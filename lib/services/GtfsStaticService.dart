import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:transitapp/models/Stop.dart';


class GtfsTrip {
  final String routeId;
  final String headsign;
  final int directionId;
  final String serviceId;
  final String shapeId;
  GtfsTrip(this.routeId, this.headsign, this.directionId, this.serviceId, this.shapeId);
}

class _ScheduledDep {
  final String tripId;
  final int departureSec; // seconds since midnight (may exceed 86400 for overnight)
  _ScheduledDep(this.tripId, this.departureSec);
}

/// Singleton that provides GTFS static data lookups.
///
/// On first launch, stops fall back to the bundled [assets/stops.txt].
/// The GTFS static ZIP is cached on disk and refreshed weekly.
class GtfsStaticService {
  static final GtfsStaticService _instance = GtfsStaticService._();
  factory GtfsStaticService() => _instance;
  GtfsStaticService._();

  // stop_code (public number on the sign) → GTFS stop_id (internal)
  final Map<int, String> _stopCodeToId = {};
  // stop_id → stop_code (reverse lookup)
  final Map<String, int> _stopIdToCode = {};
  // All stops with coordinates (for proximity search)
  final List<Stop> _allStops = [];
  // route_id → route_short_name (e.g. "049", "099 B-Line")
  final Map<String, String> _routes = {};
  // route_short_name (stripped of leading zeros) → route_id
  final Map<String, String> _routeShortToId = {};
  // route_id → route_color hex (e.g. "d04110"), empty if not set
  final Map<String, String> _routeColors = {};
  // shape_id → ordered LatLng points
  final Map<String, List<LatLng>> _shapes = {};
  // trip_id → trip info
  final Map<String, GtfsTrip> _trips = {};
  // service_ids running today (from calendar.txt + calendar_dates.txt)
  final Set<String> _activeServiceIds = {};
  // service_ids from yesterday only — used to admit overnight GTFS trips (departure_time >= 24:00)
  final Set<String> _yesterdayServiceIds = {};
  bool _calendarLoaded = false;
  // stop_id → scheduled departures for today's active trips
  final Map<String, List<_ScheduledDep>> _stopTimes = {};
  // trip_id → stop_ids in order
  final Map<String, List<String>> _tripStops = {};
  // stop_id → Stop (for O(1) lookup)
  final Map<String, Stop> _stopById = {};

  bool _stopsLoaded = false;
  bool _staticLoaded = false;
  Future<void>? _loadFuture;
  // Throttle failed download retries within a session (5-minute cooldown).
  DateTime? _lastStaticAttempt;

  static const _cacheFileName = 'gtfs_static.zip';
  static const _cacheTimestampFileName = 'gtfs_static_ts.txt';
  static const _cacheMaxAgeDays = 7;

  // ── Public API ─────────────────────────────────────────────────────────────

  bool get hasRoutesLoaded => _routes.isNotEmpty;

  /// Deletes the on-disk cache so the next [ensureLoaded] call re-downloads.
  Future<void> invalidateCache() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final zipFile = File('${cacheDir.path}/$_cacheFileName');
      final tsFile = File('${cacheDir.path}/$_cacheTimestampFileName');
      if (zipFile.existsSync()) await zipFile.delete();
      if (tsFile.existsSync()) await tsFile.delete();
    } catch (_) {}
    _staticLoaded = false;
    _stopsLoaded = false;
    _loadFuture = null;
  }

  /// Must be awaited before calling any other method.
  Future<void> ensureLoaded() {
    if (_stopsLoaded && _staticLoaded) return Future.value();
    return _loadFuture ??= _doLoad().catchError((e, st) {
      debugPrint('GtfsStaticService: load error: $e');
      _loadFuture = null; // allow retry next call
      if (!_stopsLoaded) {
        return _loadStopsAsset().then((_) { _stopsLoaded = true; });
      }
    });
  }

  Future<void> _doLoad() async {

    final cacheDir = await getApplicationCacheDirectory();
    final zipFile = File('${cacheDir.path}/$_cacheFileName');
    final tsFile = File('${cacheDir.path}/$_cacheTimestampFileName');

    // Determine if the cached ZIP is still fresh enough.
    bool cacheValid = false;
    if (zipFile.existsSync() && tsFile.existsSync()) {
      final ts = DateTime.tryParse((await tsFile.readAsString()).trim());
      cacheValid =
          ts != null && DateTime.now().difference(ts).inDays < _cacheMaxAgeDays;
    }

    List<int>? zipBytes;

    if (cacheValid) {
      debugPrint('GtfsStaticService: using cached ZIP (< $_cacheMaxAgeDays days old)');
      zipBytes = await zipFile.readAsBytes();
    } else {
      // Only attempt download if we haven't tried recently this session.
      final now = DateTime.now();
      if (_lastStaticAttempt == null ||
          now.difference(_lastStaticAttempt!).inSeconds >= 30) {
        _lastStaticAttempt = now;
        zipBytes = await _downloadZipBytes();
        if (zipBytes != null) {
          await zipFile.writeAsBytes(zipBytes);
          await tsFile.writeAsString(now.toIso8601String());
          debugPrint('GtfsStaticService: saved new ZIP to cache');
        }
      }
      // Graceful degradation: use stale cache if download failed.
      if (zipBytes == null && zipFile.existsSync()) {
        debugPrint('GtfsStaticService: download failed, using stale cache');
        zipBytes = await zipFile.readAsBytes();
      }
    }

    if (zipBytes != null) {
      _parseZipBytes(zipBytes);
      _stopsLoaded = true;
      _staticLoaded = true;
    } else {
      // No ZIP at all (first launch, no network) — load stops from bundled asset.
      if (!_stopsLoaded) {
        debugPrint('GtfsStaticService: no ZIP available, loading stops from asset');
        await _loadStopsAsset();
        _stopsLoaded = true;
      }
    }
  }

  /// Stops within [radiusMeters] of ([lat], [lng]).
  List<Stop> getStopsNear(double lat, double lng, double radiusMeters) {
    final out = <Stop>[];
    for (final s in _allStops) {
      if (s.Latitude == null || s.Longitude == null) continue;
      if (_distM(lat, lng, s.Latitude!, s.Longitude!) <= radiusMeters) {
        out.add(s);
      }
    }
    return out;
  }

  /// Returns the scheduled Unix epoch seconds for [tripId] at [stopId], or null.
  int? getScheduledEpoch(String tripId, String stopId) {
    final dep = _stopTimes[stopId]?.firstWhere(
      (d) => d.tripId == tripId,
      orElse: () => _ScheduledDep('', -1),
    );
    if (dep == null || dep.departureSec < 0) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final midnight = dep.departureSec >= 86400
        ? today.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000
        : today.millisecondsSinceEpoch ~/ 1000;
    return midnight + dep.departureSec;
  }

  String? getStopId(int stopCode) => _stopCodeToId[stopCode];
  int? getStopCode(String stopId) => _stopIdToCode[stopId];
  Stop? getStopByCode(int stopCode) {
    for (final s in _allStops) {
      if (s.StopNo == stopCode) return s;
    }
    return null;
  }
  String? getRouteShortName(String routeId) => _routes[routeId];
  GtfsTrip? getTripInfo(String tripId) => _trips[tripId];

  /// Returns the route color for [routeNo], defaulting to a blue toned to [isDark].
  Color getRouteColor(String routeNo, {bool isDark = false}) {
    final routeId = _routeShortToId[_stripZeros(routeNo)];
    final hex = routeId != null ? _routeColors[routeId] : null;
    if (hex != null && hex.length == 6) {
      final r = int.tryParse(hex.substring(0, 2), radix: 16);
      final g = int.tryParse(hex.substring(2, 4), radix: 16);
      final b = int.tryParse(hex.substring(4, 6), radix: 16);
      if (r != null && g != null && b != null) {
        return Color.fromARGB(255, r, g, b);
      }
    }
    return isDark ? const Color.fromARGB(255, 40, 92, 176) : const Color(0xFF1b2336);
  }

  /// Returns all route IDs (GTFS internal) for routes that serve [stopId] today.
  Set<String> getRouteIdsServingStop(String stopId) {
    final deps = _stopTimes[stopId];
    if (deps == null) return {};
    return deps
        .map((d) => _trips[d.tripId]?.routeId)
        .whereType<String>()
        .toSet();
  }

  /// Returns true if [tripId]'s scheduled stops include [stopId].
  bool doesTripServeStop(String tripId, String stopId) {
    return _tripStops[tripId]?.contains(stopId) ?? false;
  }

  /// Returns the ordered stops for a specific [tripId].
  List<Stop> getStopsForTrip(String tripId) {
    final stopIds = _tripStops[tripId];
    if (stopIds == null) return [];
    return stopIds.map((id) => _stopById[id]).whereType<Stop>().toList();
  }

  /// Returns the shape for a specific [tripId], or null if not found.
  List<LatLng>? getShapeForTrip(String tripId) {
    final shapeId = _trips[tripId]?.shapeId;
    if (shapeId == null || shapeId.isEmpty) return null;
    return _shapes[shapeId];
  }

  /// Returns all distinct route shapes for [routeNo] (e.g. "049" or "099").
  /// Matches against GTFS route_short_name with leading zeros stripped.
  List<List<LatLng>> getShapesForRoute(String routeNo) {
    final routeId = _routeShortToId[_stripZeros(routeNo)];
    if (routeId == null) return [];
    final seen = <String>{};
    final result = <List<LatLng>>[];
    for (final trip in _trips.values) {
      if (trip.routeId != routeId) continue;
      if (trip.shapeId.isEmpty || !seen.add(trip.shapeId)) continue;
      final pts = _shapes[trip.shapeId];
      if (pts != null && pts.isNotEmpty) result.add(pts);
    }
    return result;
  }

  /// Returns a representative trip ID for [routeNo] and [directionId], or null.
  String? getRepresentativeTripId(String routeNo, {int? directionId}) {
    final routeId = _routeShortToId[_stripZeros(routeNo)];
    if (routeId == null) return null;
    for (final entry in _trips.entries) {
      if (entry.value.routeId != routeId) continue;
      if (directionId != null && entry.value.directionId != directionId) continue;
      return entry.key;
    }
    return null;
  }

  /// Returns shapes for [routeNo] filtered to [directionId] (0 or 1).
  List<List<LatLng>> getShapesForRouteAndDirection(String routeNo, int directionId) {
    final routeId = _routeShortToId[_stripZeros(routeNo)];
    if (routeId == null) return [];
    final seen = <String>{};
    final result = <List<LatLng>>[];
    for (final trip in _trips.values) {
      if (trip.routeId != routeId) continue;
      if (trip.directionId != directionId) continue;
      if (trip.shapeId.isEmpty || !seen.add(trip.shapeId)) continue;
      final pts = _shapes[trip.shapeId];
      if (pts != null && pts.isNotEmpty) result.add(pts);
    }
    return result;
  }

  static String _stripZeros(String s) {
    final trimmed = s.trim();
    final match = RegExp(r'^0+(\d.*)$').firstMatch(trimmed);
    return match != null ? match.group(1)! : trimmed;
  }

  /// Scheduled departures from stop_times.txt for [stopId] in the next 90 min.
  /// Returns (tripId, epochSec) pairs sorted by departure time.
  List<(String, int)> getScheduledDepartures(String stopId) {
    final deps = _stopTimes[stopId];
    if (deps == null || deps.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayMidnight = today.millisecondsSinceEpoch ~/ 1000;
    final yesterdayMidnight = yesterday.millisecondsSinceEpoch ~/ 1000;
    final nowEpoch = now.millisecondsSinceEpoch ~/ 1000;

    final result = <(String, int)>[];
    for (final d in deps) {
      // GTFS overnight trips use departure_time >= 24:00:00 and belong to the
      // previous service day, so base their epoch off yesterday's midnight.
      final epochSec = d.departureSec >= 86400
          ? yesterdayMidnight + d.departureSec
          : todayMidnight + d.departureSec;
      if (epochSec < nowEpoch - 120) continue;
      result.add((d.tripId, epochSec));
    }
    result.sort((a, b) => a.$2.compareTo(b.$2));
    return result;
  }

  // ── Download ───────────────────────────────────────────────────────────────

  Future<List<int>?> _downloadZipBytes() async {
    try {
      debugPrint('GtfsStaticService: downloading static ZIP...');
      final resp = await http
          .get(Uri.parse(
              'https://gtfs-static.translink.ca/gtfs/google_transit.zip'))
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) {
        debugPrint(
            'GtfsStaticService: HTTP ${resp.statusCode} — ${resp.reasonPhrase}');
        return null;
      }
      debugPrint(
          'GtfsStaticService: downloaded ${resp.bodyBytes.length} bytes');
      return resp.bodyBytes;
    } catch (e) {
      debugPrint('GtfsStaticService: download failed: $e');
      return null;
    }
  }

  // ── Parsing ────────────────────────────────────────────────────────────────

  void _parseZipBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    // stop_times.txt must be parsed after trips + calendar; save bytes for second pass.
    List<int>? stopTimesBytes;
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.toLowerCase().split('/').last;
      if (name == 'stop_times.txt') {
        stopTimesBytes = file.content as List<int>;
        continue;
      }
      final content = utf8.decode(file.content as List<int>, allowMalformed: true);
      if (name == 'stops.txt') _parseStops(content);
      if (name == 'routes.txt') _parseRoutes(content);
      if (name == 'trips.txt') _parseTrips(content);
      if (name == 'shapes.txt') _parseShapes(content);
      if (name == 'calendar.txt') _parseCalendar(content);
      if (name == 'calendar_dates.txt') _parseCalendarDates(content);
    }
    if (stopTimesBytes != null) {
      _parseStopTimes(utf8.decode(stopTimesBytes, allowMalformed: true));
    }
    debugPrint('GtfsStaticService: ${_allStops.length} stops, ${_routes.length} routes, '
        '${_trips.length} trips, ${_stopTimes.length} stops with scheduled times');
  }

  // ── Stops asset (fallback) ─────────────────────────────────────────────────

  Future<void> _loadStopsAsset() async {
    final csv = await rootBundle.loadString('assets/stops.txt');
    _parseStops(csv);
  }

  void _parseStops(String csv) {
    final lines = csv.split('\n');
    if (lines.isEmpty) return;

    final header = _csvRow(lines[0]);
    final idCol = header.indexOf('stop_id');
    final codeCol = header.indexOf('stop_code');
    final nameCol = header.indexOf('stop_name');
    final latCol = header.indexOf('stop_lat');
    final lonCol = header.indexOf('stop_lon');
    final wchCol = header.indexOf('wheelchair_boarding');

    for (int i = 1; i < lines.length; i++) {
      final row = _csvRow(lines[i]);
      if (row.length <= max(idCol, max(codeCol, max(latCol, lonCol)))) continue;

      final stopId = row[idCol].trim();
      final stopCode = int.tryParse(row[codeCol].trim());
      final lat = double.tryParse(row[latCol].trim());
      final lon = double.tryParse(row[lonCol].trim());

      if (stopId.isEmpty || stopCode == null || lat == null || lon == null) {
        continue;
      }

      _stopCodeToId[stopCode] = stopId;
      _stopIdToCode[stopId] = stopCode;

      final name =
          nameCol >= 0 && nameCol < row.length ? row[nameCol].trim() : null;
      String? onStreet, atStreet;
      if (name != null && name.contains('@')) {
        onStreet = name.split('@')[0];
        atStreet = name.split('@')[1];
      } else if (name != null) {
        onStreet = name;
        atStreet = '';
      }

      final stop = Stop(
        StopNo: stopCode,
        Name: name,
        OnStreet: onStreet,
        AtStreet: atStreet,
        Latitude: lat,
        Longitude: lon,
        WheelchairAccess: wchCol >= 0 && wchCol < row.length
            ? int.tryParse(row[wchCol].trim())
            : null,
      );
      _allStops.add(stop);
      _stopById[stopId] = stop;
    }
  }

  void _parseRoutes(String csv) {
    final lines = csv.split('\n');
    if (lines.isEmpty) return;
    final header = _csvRow(lines[0]);
    final idCol = header.indexOf('route_id');
    final shortCol = header.indexOf('route_short_name');
    final colorCol = header.indexOf('route_color');
    if (idCol < 0 || shortCol < 0) return;

    for (int i = 1; i < lines.length; i++) {
      final row = _csvRow(lines[i]);
      if (row.length <= max(idCol, shortCol)) continue;
      final id = row[idCol].trim();
      final name = row[shortCol].trim();
      if (id.isNotEmpty && name.isNotEmpty) {
        _routes[id] = name;
        _routeShortToId[_stripZeros(name)] = id;
        if (colorCol >= 0 && colorCol < row.length) {
          final color = row[colorCol].trim();
          if (color.isNotEmpty) _routeColors[id] = color;
        }
      }
    }
  }

  void _parseTrips(String csv) {
    final lines = csv.split('\n');
    if (lines.isEmpty) return;
    final header = _csvRow(lines[0]);
    final tripIdCol = header.indexOf('trip_id');
    final routeIdCol = header.indexOf('route_id');
    final headsignCol = header.indexOf('trip_headsign');
    final dirCol = header.indexOf('direction_id');
    final serviceIdCol = header.indexOf('service_id');
    final shapeIdCol = header.indexOf('shape_id');
    if (tripIdCol < 0) return;

    for (int i = 1; i < lines.length; i++) {
      final row = _csvRow(lines[i]);
      if (row.length <= tripIdCol) continue;
      final tripId = row[tripIdCol].trim();
      if (tripId.isEmpty) continue;
      final routeId = routeIdCol >= 0 && routeIdCol < row.length
          ? row[routeIdCol].trim()
          : '';
      final headsign = headsignCol >= 0 && headsignCol < row.length
          ? row[headsignCol].trim()
          : '';
      final dirId = dirCol >= 0 && dirCol < row.length
          ? (int.tryParse(row[dirCol].trim()) ?? 0)
          : 0;
      final serviceId = serviceIdCol >= 0 && serviceIdCol < row.length
          ? row[serviceIdCol].trim()
          : '';
      final shapeId = shapeIdCol >= 0 && shapeIdCol < row.length
          ? row[shapeIdCol].trim()
          : '';
      _trips[tripId] = GtfsTrip(routeId, headsign, dirId, serviceId, shapeId);
    }
  }

  void _parseShapes(String csv) {
    final lines = csv.split('\n');
    if (lines.isEmpty) return;
    final header = lines[0].split(',');
    final idCol = header.indexOf('shape_id');
    final latCol = header.indexOf('shape_pt_lat');
    final lonCol = header.indexOf('shape_pt_lon');
    final seqCol = header.indexOf('shape_pt_sequence');
    if (idCol < 0 || latCol < 0 || lonCol < 0) return;

    // Accumulate points per shape as (sequence, LatLng).
    final Map<String, List<(int, LatLng)>> raw = {};
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final row = line.split(',');
      if (row.length <= max(idCol, max(latCol, lonCol))) continue;
      final shapeId = row[idCol].trim();
      final lat = double.tryParse(row[latCol].trim());
      final lon = double.tryParse(row[lonCol].trim());
      if (shapeId.isEmpty || lat == null || lon == null) continue;
      final seq = seqCol >= 0 && seqCol < row.length
          ? (int.tryParse(row[seqCol].trim()) ?? 0)
          : 0;
      raw.putIfAbsent(shapeId, () => []).add((seq, LatLng(lat, lon)));
    }

    for (final entry in raw.entries) {
      final pts = entry.value..sort((a, b) => a.$1.compareTo(b.$1));
      _shapes[entry.key] = pts.map((p) => p.$2).toList();
    }
    debugPrint('GtfsStaticService: ${_shapes.length} shapes loaded');
  }

  void _parseCalendar(String csv) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final todayStr = _dateStr(now);
    final yesterdayStr = _dateStr(yesterday);
    const dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayName = dayNames[now.weekday - 1];
    final yesterdayName = dayNames[yesterday.weekday - 1];

    final lines = csv.split('\n');
    if (lines.isEmpty) return;
    final header = _csvRow(lines[0]);
    final svcCol = header.indexOf('service_id');
    final startCol = header.indexOf('start_date');
    final endCol = header.indexOf('end_date');
    if (svcCol < 0) return;

    final todayDayCol = header.indexOf(dayName);
    final yestDayCol = header.indexOf(yesterdayName);

    for (int i = 1; i < lines.length; i++) {
      final row = _csvRow(lines[i]);
      if (row.length <= svcCol) continue;
      final svcId = row[svcCol].trim();
      if (svcId.isEmpty) continue;
      final start = startCol >= 0 && startCol < row.length ? row[startCol].trim() : '';
      final end = endCol >= 0 && endCol < row.length ? row[endCol].trim() : '';

      if (todayDayCol >= 0 && todayDayCol < row.length && row[todayDayCol].trim() == '1') {
        if ((start.isEmpty || todayStr.compareTo(start) >= 0) &&
            (end.isEmpty || todayStr.compareTo(end) <= 0)) {
          _activeServiceIds.add(svcId);
        }
      }
      // Track yesterday's service separately — only overnight trips (departureSec >= 86400)
      // from these IDs will be admitted in _parseStopTimes.
      if (yestDayCol >= 0 && yestDayCol < row.length && row[yestDayCol].trim() == '1') {
        if ((start.isEmpty || yesterdayStr.compareTo(start) >= 0) &&
            (end.isEmpty || yesterdayStr.compareTo(end) <= 0)) {
          _yesterdayServiceIds.add(svcId);
        }
      }
    }
    _calendarLoaded = true;
  }

  void _parseCalendarDates(String csv) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final todayStr = _dateStr(now);
    final yesterdayStr = _dateStr(yesterday);

    final lines = csv.split('\n');
    if (lines.isEmpty) return;
    final header = _csvRow(lines[0]);
    final svcCol = header.indexOf('service_id');
    final dateCol = header.indexOf('date');
    final exCol = header.indexOf('exception_type');
    if (svcCol < 0 || dateCol < 0 || exCol < 0) return;

    for (int i = 1; i < lines.length; i++) {
      final row = _csvRow(lines[i]);
      if (row.length <= max(svcCol, max(dateCol, exCol))) continue;
      final rowDate = row[dateCol].trim();
      final svcId = row[svcCol].trim();
      final ex = int.tryParse(row[exCol].trim());
      if (rowDate == todayStr) {
        if (ex == 1) { _activeServiceIds.add(svcId); _calendarLoaded = true; }
        else if (ex == 2) _activeServiceIds.remove(svcId);
      } else if (rowDate == yesterdayStr) {
        if (ex == 1) _yesterdayServiceIds.add(svcId);
        else if (ex == 2) _yesterdayServiceIds.remove(svcId);
      }
    }
  }

  void _parseStopTimes(String csv) {
    final lines = csv.split('\n');
    if (lines.isEmpty) return;

    // Use simple split — stop_times fields are never quoted
    final headerParts = lines[0].split(',');
    final tripIdCol = headerParts.indexOf('trip_id');
    final depCol = headerParts.indexOf('departure_time');
    final stopIdCol = headerParts.indexOf('stop_id');
    final seqCol = headerParts.indexOf('stop_sequence');
    if (tripIdCol < 0 || depCol < 0 || stopIdCol < 0) return;

    final needCols = max(tripIdCol, max(depCol, stopIdCol));

    // temp buffer for building ordered stop lists: trip_id → [(seq, stopId)]
    final Map<String, List<(int, String)>> tripStopsTemp = {};

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final row = line.split(',');
      if (row.length <= needCols) continue;

      final tripId = row[tripIdCol].trim();
      if (tripId.isEmpty) continue;

      final stopId = row[stopIdCol].trim();
      if (stopId.isEmpty) continue;

      final depStr = row[depCol].trim();
      final depSec = depStr.isNotEmpty ? _parseTimeSec(depStr) : -1;

      // Filter to active trips only when calendar data is available
      if (_calendarLoaded) {
        final trip = _trips[tripId];
        if (trip == null) continue;
        final isToday = _activeServiceIds.contains(trip.serviceId);
        final isYesterday = !isToday && _yesterdayServiceIds.contains(trip.serviceId);
        if (!isToday && !isYesterday) continue;
        if (depSec >= 0) {
          // Only admit yesterday-service trips if they're overnight (>= 24:00).
          if (!isYesterday || depSec >= 86400) {
            _stopTimes.putIfAbsent(stopId, () => []).add(_ScheduledDep(tripId, depSec));
          }
        }
      } else {
        if (!_trips.containsKey(tripId)) continue;
        if (depSec >= 0) {
          _stopTimes.putIfAbsent(stopId, () => []).add(_ScheduledDep(tripId, depSec));
        }
      }

      final seq = seqCol >= 0 && seqCol < row.length
          ? (int.tryParse(row[seqCol].trim()) ?? 0)
          : 0;
      tripStopsTemp.putIfAbsent(tripId, () => []).add((seq, stopId));
    }

    for (final entry in tripStopsTemp.entries) {
      entry.value.sort((a, b) => a.$1.compareTo(b.$1));
      _tripStops[entry.key] = entry.value.map((e) => e.$2).toList();
    }
  }

  static String _dateStr(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  static int _parseTimeSec(String hms) {
    final parts = hms.split(':');
    if (parts.length != 3) return -1;
    final h = int.tryParse(parts[0]) ?? -1;
    final m = int.tryParse(parts[1]) ?? -1;
    final s = int.tryParse(parts[2]) ?? -1;
    if (h < 0 || m < 0 || s < 0) return -1;
    return h * 3600 + m * 60 + s;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Split a CSV row, respecting double-quoted fields.
  static List<String> _csvRow(String line) {
    if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
    final fields = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        fields.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    fields.add(buf.toString());
    return fields;
  }

  /// Approximate distance in metres between two lat/lng points.
  static double _distM(double lat1, double lng1, double lat2, double lng2) {
    const degToRad = pi / 180;
    final dLat = (lat2 - lat1) * 111000;
    final dLng = (lng2 - lng1) * 111000 * cos(lat1 * degToRad);
    return sqrt(dLat * dLat + dLng * dLng);
  }
}
