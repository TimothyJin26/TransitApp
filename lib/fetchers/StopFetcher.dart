import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/services/GtfsStaticService.dart';

class StopFetcher {
  Future<List<Stop>> stopFetcher(String latitude, String longitude) async {
    final lat = double.tryParse(latitude);
    final lng = double.tryParse(longitude);
    if (lat == null || lng == null) return [];

    await GtfsStaticService().ensureLoaded();
    return GtfsStaticService().getStopsNear(lat, lng, 500);
  }
}
