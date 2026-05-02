import 'package:flutter/foundation.dart';
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
  // trip_id → best delay estimate in seconds (from whichever stop the feed provided)
  Map<String, int>? _tripDelayMap;
  Set<String>? _cancelledTripIds;

  void invalidateCache() {
    _tripUpdatesAt = null;
    _tripUpdateIndex = null;
    _tripDelayMap = null;
    _cancelledTripIds = null;
    _vehiclePositionsAt = null;
  }

  Future<List<GtfsTripUpdate>> getTripUpdates() async {
    if (_isFresh(_tripUpdatesAt) && _tripUpdates != null) return _tripUpdates!;
    try {
      final resp = await http
          .get(Uri.parse(
              'https://gtfsapi.translink.ca/v3/gtfsrealtime?apikey=$_apiKey'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _tripUpdates = await compute(GtfsRealtimeReader.parseTripUpdates, resp.bodyBytes);
        _tripUpdatesAt = DateTime.now();
        _tripUpdateIndex = null;
      }
    } catch (_) {}
    return _tripUpdates ?? [];
  }

  /// Returns all upcoming departures for [stopId], sorted by time.
  Future<List<StopEntry>> getDeparturesForStop(String stopId) async {
    final updates = await getTripUpdates();
    _ensureIndexes(updates);
    return _tripUpdateIndex![stopId] ?? [];
  }

  /// Returns `(cancelled, delay)` for [tripId] from the RT feed.
  /// `cancelled` is true if the trip is marked CANCELED.
  /// `delay` is the delay in seconds if the trip is live, or null if not in the feed.
  Future<({bool cancelled, int? delay})> getTripStatus(String tripId) async {
    final updates = await getTripUpdates();
    _ensureIndexes(updates);
    return (
      cancelled: _cancelledTripIds!.contains(tripId),
      delay: _tripDelayMap![tripId],
    );
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
        final fresh = await compute(GtfsRealtimeReader.parseVehiclePositions, resp.bodyBytes);
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

  void _ensureIndexes(List<GtfsTripUpdate> updates) {
    if (_tripUpdateIndex != null) return;
    final index = <String, List<StopEntry>>{};
    final delays = <String, int>{};
    final cancelled = <String>{};
    for (final tu in updates) {
      if (tu.cancelled) {
        cancelled.add(tu.tripId);
        continue;
      }
      for (final stu in tu.stopTimeUpdates) {
        index.putIfAbsent(stu.stopId, () => []).add(StopEntry(tu, stu));
      }
      if (tu.stopTimeUpdates.isNotEmpty) {
        delays[tu.tripId] = tu.stopTimeUpdates.first.delay ?? 0;
      }
    }
    _tripUpdateIndex = index;
    _tripDelayMap = delays;
    _cancelledTripIds = cancelled;
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
