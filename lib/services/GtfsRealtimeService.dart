import 'package:http/http.dart' as http;
import 'package:transitapp/proto/GtfsRealtimeReader.dart';

const _apiKey = 'perA9biw6Ipc8aobcMa3';
const _cacheSeconds = 30;
// How long to keep showing a vehicle after it drops from the live feed.
const _positionTtlSeconds = 120;

/// Singleton that fetches and caches GTFS Realtime feeds.
class GtfsRealtimeService {
  static final GtfsRealtimeService _instance = GtfsRealtimeService._();
  factory GtfsRealtimeService() => _instance;
  GtfsRealtimeService._();

  List<GtfsTripUpdate>? _tripUpdates;
  DateTime? _tripUpdatesAt;

  List<GtfsVehiclePosition>? _vehiclePositions;
  DateTime? _vehiclePositionsAt;

  // Last-known position cache keyed by tripId (always present, unlike vehicleId).
  final Map<String, _CachedPosition> _positionCache = {};

  // Index: stop_id → list of (tripUpdate, stopTimeUpdate) for fast lookup
  Map<String, List<StopEntry>>? _tripUpdateIndex;

  void invalidateCache() {
    _tripUpdatesAt = null;
    _tripUpdateIndex = null;
  }

  Future<List<GtfsTripUpdate>> getTripUpdates() async {
    if (_isFresh(_tripUpdatesAt) && _tripUpdates != null) return _tripUpdates!;
    try {
      final resp = await http
          .get(Uri.parse(
              'https://gtfsapi.translink.ca/v3/gtfsrealtime?apikey=$_apiKey'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _tripUpdates = GtfsRealtimeReader.parseTripUpdates(resp.bodyBytes);
        _tripUpdatesAt = DateTime.now();
        _tripUpdateIndex = null;
      }
    } catch (_) {}
    return _tripUpdates ?? [];
  }

  /// Returns all upcoming departures for [stopId], sorted by time.
  Future<List<StopEntry>> getDeparturesForStop(String stopId) async {
    final updates = await getTripUpdates();
    _tripUpdateIndex ??= _buildIndex(updates);
    return _tripUpdateIndex![stopId] ?? [];
  }

  /// Returns trip IDs of all trips currently departing from [stopId].
  Future<Set<String>> getTripIdsForStop(String stopId) async {
    final entries = await getDeparturesForStop(stopId);
    return entries.map((e) => e.tripUpdate.tripId).toSet();
  }

  Future<List<GtfsVehiclePosition>> getVehiclePositions() async {
    if (_isFresh(_vehiclePositionsAt) && _vehiclePositions != null) {
      return _vehiclePositions!;
    }
    try {
      final resp = await http
          .get(Uri.parse(
              'https://gtfsapi.translink.ca/v3/gtfsposition?apikey=$_apiKey'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final fresh = GtfsRealtimeReader.parseVehiclePositions(resp.bodyBytes);
        final now = DateTime.now();

        // Update last-known cache and stamp lastSeen on each fresh position.
        for (final v in fresh) {
          v.lastSeen = now;
          if (v.tripId.isNotEmpty) {
            _positionCache[v.tripId] = _CachedPosition(v, now);
          }
        }

        // Merge in any recently-seen vehicles that dropped from this fetch.
        final freshTripIds = fresh.map((v) => v.tripId).toSet();
        final merged = List<GtfsVehiclePosition>.from(fresh);
        for (final entry in _positionCache.entries) {
          if (freshTripIds.contains(entry.key)) continue;
          final age = now.difference(entry.value.seenAt).inSeconds;
          if (age <= _positionTtlSeconds) {
            merged.add(entry.value.position);
          }
        }

        _vehiclePositions = merged;
        _vehiclePositionsAt = now;
      }
    } catch (_) {}
    return _vehiclePositions ?? [];
  }

  bool _isFresh(DateTime? ts) =>
      ts != null &&
      DateTime.now().difference(ts).inSeconds < _cacheSeconds;

  static Map<String, List<StopEntry>> _buildIndex(
      List<GtfsTripUpdate> updates) {
    final index = <String, List<StopEntry>>{};
    for (final tu in updates) {
      for (final stu in tu.stopTimeUpdates) {
        index.putIfAbsent(stu.stopId, () => []).add(StopEntry(tu, stu));
      }
    }
    return index;
  }
}

class _CachedPosition {
  final GtfsVehiclePosition position;
  final DateTime seenAt;
  _CachedPosition(this.position, this.seenAt);
}

class StopEntry {
  final GtfsTripUpdate tripUpdate;
  final GtfsStopTimeUpdate stopTimeUpdate;
  StopEntry(this.tripUpdate, this.stopTimeUpdate);
}
