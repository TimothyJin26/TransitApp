import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:transitapp/models/Stop.dart';


class _GtfsTrip {
  final String routeId;
  final String headsign;
  final int directionId;
  final String serviceId;
  _GtfsTrip(this.routeId, this.headsign, this.directionId, this.serviceId);
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
  // route_id → route_short_name (e.g. "49", "99 B-Line")
  final Map<String, String> _routes = {};
  // trip_id → trip info
  final Map<String, _GtfsTrip> _trips = {};
  // service_ids running today (from calendar.txt + calendar_dates.txt)
  final Set<String> _activeServiceIds = {};
  bool _calendarLoaded = false;
  // stop_id → scheduled departures for today's active trips
  final Map<String, List<_ScheduledDep>> _stopTimes = {};

  bool _stopsLoaded = false;
  bool _staticLoaded = false;
  // Throttle failed download retries within a session (5-minute cooldown).
  DateTime? _lastStaticAttempt;

  static const _cacheFileName = 'gtfs_static.zip';
  static const _cacheTimestampFileName = 'gtfs_static_ts.txt';
  static const _cacheMaxAgeDays = 7;

  // ── Public API ─────────────────────────────────────────────────────────────

  bool get hasRoutesLoaded => _routes.isNotEmpty;

  /// Must be awaited before calling any other method.
  Future<void> ensureLoaded() async {
    if (_stopsLoaded && _staticLoaded) return;

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
          now.difference(_lastStaticAttempt!).inMinutes >= 5) {
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

  String? getStopId(int stopCode) => _stopCodeToId[stopCode];
  int? getStopCode(String stopId) => _stopIdToCode[stopId];
  Stop? getStopByCode(int stopCode) {
    for (final s in _allStops) {
      if (s.StopNo == stopCode) return s;
    }
    return null;
  }
  String? getRouteShortName(String routeId) => _routes[routeId];
  _GtfsTrip? getTripInfo(String tripId) => _trips[tripId];

  /// Scheduled departures from stop_times.txt for [stopId] in the next 90 min.
  /// Returns (tripId, epochSec) pairs sorted by departure time.
  List<(String, int)> getScheduledDepartures(String stopId) {
    final deps = _stopTimes[stopId];
    if (deps == null || deps.isEmpty) return [];

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final midnightEpoch = midnight.millisecondsSinceEpoch ~/ 1000;
    final nowSec = now.hour * 3600 + now.minute * 60 + now.second;
    final windowStart = nowSec - 120; // exclude trips departed >2 min ago

    final result = <(String, int)>[];
    for (final d in deps) {
      if (d.departureSec < windowStart) continue;
      result.add((d.tripId, midnightEpoch + d.departureSec));
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

      _allStops.add(Stop(
        StopNo: stopCode,
        Name: name,
        OnStreet: onStreet,
        AtStreet: atStreet,
        Latitude: lat,
        Longitude: lon,
        WheelchairAccess: wchCol >= 0 && wchCol < row.length
            ? int.tryParse(row[wchCol].trim())
            : null,
      ));
    }
  }

  void _parseRoutes(String csv) {
    final lines = csv.split('\n');
    if (lines.isEmpty) return;
    final header = _csvRow(lines[0]);
    final idCol = header.indexOf('route_id');
    final shortCol = header.indexOf('route_short_name');
    if (idCol < 0 || shortCol < 0) return;

    for (int i = 1; i < lines.length; i++) {
      final row = _csvRow(lines[i]);
      if (row.length <= max(idCol, shortCol)) continue;
      final id = row[idCol].trim();
      final name = row[shortCol].trim();
      if (id.isNotEmpty && name.isNotEmpty) _routes[id] = name;
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
      _trips[tripId] = _GtfsTrip(routeId, headsign, dirId, serviceId);
    }
  }

  void _parseCalendar(String csv) {
    final now = DateTime.now();
    final todayStr = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    const dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayName = dayNames[now.weekday - 1];

    final lines = csv.split('\n');
    if (lines.isEmpty) return;
    final header = _csvRow(lines[0]);
    final svcCol = header.indexOf('service_id');
    final dayCol = header.indexOf(dayName);
    final startCol = header.indexOf('start_date');
    final endCol = header.indexOf('end_date');
    if (svcCol < 0 || dayCol < 0) return;

    for (int i = 1; i < lines.length; i++) {
      final row = _csvRow(lines[i]);
      if (row.length <= max(svcCol, dayCol)) continue;
      if (row[dayCol].trim() != '1') continue;
      final svcId = row[svcCol].trim();
      if (svcId.isEmpty) continue;
      final start = startCol >= 0 && startCol < row.length ? row[startCol].trim() : '';
      final end = endCol >= 0 && endCol < row.length ? row[endCol].trim() : '';
      if ((start.isEmpty || todayStr.compareTo(start) >= 0) &&
          (end.isEmpty || todayStr.compareTo(end) <= 0)) {
        _activeServiceIds.add(svcId);
      }
    }
    _calendarLoaded = true;
  }

  void _parseCalendarDates(String csv) {
    final now = DateTime.now();
    final todayStr = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';

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
      if (row[dateCol].trim() != todayStr) continue;
      final svcId = row[svcCol].trim();
      final ex = int.tryParse(row[exCol].trim());
      if (ex == 1) {
        _activeServiceIds.add(svcId);
        _calendarLoaded = true;
      } else if (ex == 2) {
        _activeServiceIds.remove(svcId);
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
    if (tripIdCol < 0 || depCol < 0 || stopIdCol < 0) return;

    final needCols = max(tripIdCol, max(depCol, stopIdCol));

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final row = line.split(',');
      if (row.length <= needCols) continue;

      final tripId = row[tripIdCol].trim();
      if (tripId.isEmpty) continue;

      // Filter to active trips only when calendar data is available
      if (_calendarLoaded) {
        final trip = _trips[tripId];
        if (trip == null || !_activeServiceIds.contains(trip.serviceId)) continue;
      } else {
        if (!_trips.containsKey(tripId)) continue;
      }

      final depStr = row[depCol].trim();
      final stopId = row[stopIdCol].trim();
      if (depStr.isEmpty || stopId.isEmpty) continue;

      final depSec = _parseTimeSec(depStr);
      if (depSec < 0) continue;

      _stopTimes.putIfAbsent(stopId, () => []).add(_ScheduledDep(tripId, depSec));
    }
  }

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
