import 'package:http/http.dart' as http;
import 'package:transitapp/proto/GtfsRealtimeReader.dart';

const _apiKey = 'perA9biw6Ipc8aobcMa3';
const _cacheSeconds = 30;

/// Singleton that fetches and caches GTFS Realtime feeds.
class GtfsRealtimeService {
  static final GtfsRealtimeService _instance = GtfsRealtimeService._();
  factory GtfsRealtimeService() => _instance;
  GtfsRealtimeService._();

  List<GtfsTripUpdate>? _tripUpdates;
  DateTime? _tripUpdatesAt;

  List<GtfsVehiclePosition>? _vehiclePositions;
  DateTime? _vehiclePositionsAt;

  // Index: stop_id → list of (tripUpdate, stopTimeUpdate) for fast lookup
  Map<String, List<_StopEntry>>? _tripUpdateIndex;

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
        _tripUpdateIndex = null; // invalidate index
      }
    } catch (_) {}
    return _tripUpdates ?? [];
  }

  /// Returns all upcoming departures for [stopId], sorted by time.
  Future<List<_StopEntry>> getDeparturesForStop(String stopId) async {
    final updates = await getTripUpdates();
    _tripUpdateIndex ??= _buildIndex(updates);
    return _tripUpdateIndex![stopId] ?? [];
  }

  Future<List<GtfsVehiclePosition>> getVehiclePositions() async {
    if (_isFresh(_vehiclePositionsAt) && _vehiclePositions != null) return _vehiclePositions!;
    try {
      final resp = await http
          .get(Uri.parse(
              'https://gtfsapi.translink.ca/v3/gtfsposition?apikey=$_apiKey'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _vehiclePositions =
            GtfsRealtimeReader.parseVehiclePositions(resp.bodyBytes);
        _vehiclePositionsAt = DateTime.now();
      }
    } catch (_) {}
    return _vehiclePositions ?? [];
  }

  bool _isFresh(DateTime? ts) =>
      ts != null &&
      DateTime.now().difference(ts).inSeconds < _cacheSeconds;

  static Map<String, List<_StopEntry>> _buildIndex(
      List<GtfsTripUpdate> updates) {
    final index = <String, List<_StopEntry>>{};
    for (final tu in updates) {
      for (final stu in tu.stopTimeUpdates) {
        index.putIfAbsent(stu.stopId, () => []).add(_StopEntry(tu, stu));
      }
    }
    return index;
  }
}

class _StopEntry {
  final GtfsTripUpdate tripUpdate;
  final GtfsStopTimeUpdate stopTimeUpdate;
  _StopEntry(this.tripUpdate, this.stopTimeUpdate);
}
