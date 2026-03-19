import 'package:transitapp/models/Trip.dart';
import 'package:transitapp/services/GtfsRealtimeService.dart';
import 'package:transitapp/services/GtfsStaticService.dart';
import 'package:transitapp/util/GtfsUtil.dart';

class NextBusesForRouteAtStop {
  Future<List<Trip>> busAtSingleStopFetcher(
      String stopNo, String routeNo) async {
    await GtfsStaticService().ensureLoaded();

    final stopCode = int.tryParse(stopNo);
    if (stopCode == null) return [];
    final stopId = GtfsStaticService().getStopId(stopCode);
    if (stopId == null) return [];

    final entries = await GtfsRealtimeService().getDeparturesForStop(stopId);
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final static_ = GtfsStaticService();
    final List<Trip> trips = [];

    for (final entry in entries) {
      final tu = entry.tripUpdate;
      final stu = entry.stopTimeUpdate;

      final tripInfo = static_.getTripInfo(tu.tripId);
      final routeId =
          tu.routeId.isNotEmpty ? tu.routeId : (tripInfo?.routeId ?? '');
      String thisRouteNo = static_.getRouteShortName(routeId) ?? routeId;
      while (thisRouteNo.startsWith('0')) {
        thisRouteNo = thisRouteNo.substring(1);
      }
      if (thisRouteNo != routeNo) continue;

      final departureTime = stu.time;
      if (departureTime == null) continue;
      final countdown = ((departureTime - nowSec) / 60).floor();
      if (countdown < 0) continue;

      trips.add(Trip(
        Pattern: tu.directionId == 0 ? 'Outbound' : 'Inbound',
        Destination: (tripInfo?.headsign ?? '').toUpperCase(),
        ExpectedCountdown: countdown,
        LastUpdate: DateTime.now().toIso8601String(),
        RouteNo: thisRouteNo,
        ExpectedLeaveTime: GtfsUtil.formatTime(departureTime),
      ));
    }

    trips.sort(
        (a, b) => (a.ExpectedCountdown ?? 0).compareTo(b.ExpectedCountdown ?? 0));
    return trips.take(10).toList();
  }
}
