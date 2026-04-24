import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/models/Trip.dart';
import 'package:transitapp/services/GtfsRealtimeService.dart';
import 'package:transitapp/services/GtfsStaticService.dart';
import 'package:transitapp/util/GtfsUtil.dart';

class BusAtSingleStopFetcher {
  Future<List<BothDirectionRouteWithTrips>> busAtSingleStopFetcher(
      Stop stop, String busStopNum) async {
    await GtfsStaticService().ensureLoaded();

    final stopCode = int.tryParse(busStopNum);
    if (stopCode == null) return [];
    final stopId = GtfsStaticService().getStopId(stopCode);
    if (stopId == null) return [];

    final entries = await GtfsRealtimeService().getDeparturesForStop(stopId);
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final static_ = GtfsStaticService();
    final List<BothDirectionRouteWithTrips> routeTrips = [];

    for (final entry in entries) {
      final tu = entry.tripUpdate;
      final stu = entry.stopTimeUpdate;

      final departureTime = stu.time;
      if (departureTime == null) continue;
      final countdown = ((departureTime - nowSec) / 60).floor();
      if (countdown < 0) continue;

      final tripInfo = static_.getTripInfo(tu.tripId);
      final routeId =
          tu.routeId.isNotEmpty ? tu.routeId : (tripInfo?.routeId ?? '');
      String routeNo = static_.getRouteShortName(routeId) ?? routeId;
      while (routeNo.startsWith('0')) {
        routeNo = routeNo.substring(1);
      }

      final trip = Trip(
        Pattern: GtfsUtil.directionFromStop(stop.OnStreet, tu.directionId),
        Destination: GtfsUtil.stripHeadsignPrefix(tripInfo?.headsign ?? '').toUpperCase(),
        ExpectedCountdown: countdown,
        LastUpdate: DateTime.now().toIso8601String(),
        RouteNo: routeNo,
        ExpectedLeaveTime: GtfsUtil.formatTime(departureTime),
      );
      trip.nextStop = GtfsUtil.nextStopLabel(
        name: stop.Name,
        onStreet: stop.OnStreet,
        atStreet: stop.AtStreet,
      );
      trip.StopNo = stop.StopNo.toString();

      final idx = routeTrips.indexWhere((r) => r.RouteNo == routeNo);
      if (idx < 0) {
        routeTrips.add(BothDirectionRouteWithTrips(routeNo, [trip]));
      } else {
        routeTrips[idx].Trips.add(trip);
      }
    }

    return routeTrips;
  }
}
