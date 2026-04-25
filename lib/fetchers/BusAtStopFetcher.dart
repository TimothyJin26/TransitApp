import 'dart:math';

import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/models/Trip.dart';
import 'package:transitapp/services/GtfsRealtimeService.dart';
import 'package:transitapp/services/GtfsStaticService.dart';
import 'package:transitapp/util/GtfsUtil.dart';

class BusAtStopFetcher {
  Future<List<BothDirectionRouteWithTrips>> busFetcher(
      List<Stop> stopList, double lat, double lng) async {
    await GtfsStaticService().ensureLoaded();

    stopList.sort((a, b) {
      final dA = sqrt(pow((a.Latitude ?? 0) - lat, 2) +
          pow((a.Longitude ?? 0) - lng, 2));
      final dB = sqrt(pow((b.Latitude ?? 0) - lat, 2) +
          pow((b.Longitude ?? 0) - lng, 2));
      return dA.compareTo(dB);
    });
    final nearest = stopList.sublist(0, min(stopList.length, 6));

    final static_ = GtfsStaticService();
    final rt = GtfsRealtimeService();
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final List<BothDirectionRouteWithTrips> routeTrips = [];

    for (final stop in nearest) {
      final stopId = static_.getStopId(stop.StopNo ?? 0);
      if (stopId == null) continue;

      final realtimeTripIds = <String>{};

      final entries = await rt.getDeparturesForStop(stopId);
      for (final entry in entries) {
        final tu = entry.tripUpdate;
        final stu = entry.stopTimeUpdate;

        final departureTime = stu.time;
        if (departureTime == null) continue;
        final countdown = ((departureTime - nowSec) / 60).floor();
        if (countdown < 0 || countdown > 90) continue;

        realtimeTripIds.add(tu.tripId);

        final tripInfo = static_.getTripInfo(tu.tripId);
        final routeId =
            tu.routeId.isNotEmpty ? tu.routeId : (tripInfo?.routeId ?? '');
        String routeNo = static_.getRouteShortName(routeId) ?? routeId;
        while (routeNo.startsWith('0')) routeNo = routeNo.substring(1);

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

      // Supplement with scheduled departures for trips not in the realtime feed
      final scheduled = static_.getScheduledDepartures(stopId);
      for (final (tripId, epochSec) in scheduled) {
        if (realtimeTripIds.contains(tripId)) continue;

        final countdown = ((epochSec - nowSec) / 60).floor();
        if (countdown < 0 || countdown > 90) continue;

        final tripInfo = static_.getTripInfo(tripId);
        if (tripInfo == null) continue;

        String routeNo = static_.getRouteShortName(tripInfo.routeId) ?? tripInfo.routeId;
        while (routeNo.startsWith('0')) routeNo = routeNo.substring(1);
        if (routeNo.isEmpty) continue;

        final trip = Trip(
          Pattern: GtfsUtil.directionFromStop(stop.OnStreet, tripInfo.directionId),
          Destination: GtfsUtil.stripHeadsignPrefix(tripInfo.headsign).toUpperCase(),
          ExpectedCountdown: countdown,
          LastUpdate: DateTime.now().toIso8601String(),
          RouteNo: routeNo,
          ExpectedLeaveTime: GtfsUtil.formatTime(epochSec),
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
    }

    return routeTrips;
  }
}
