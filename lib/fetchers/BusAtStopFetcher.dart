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

    // Filter to stops within 500m, then sort nearest-first.
    double distMeters(Stop s) {
      const r = 6371000.0;
      final dLat = (s.Latitude! - lat) * pi / 180;
      final dLng = (s.Longitude! - lng) * pi / 180;
      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(lat * pi / 180) * cos(s.Latitude! * pi / 180) *
          sin(dLng / 2) * sin(dLng / 2);
      return r * 2 * atan2(sqrt(a), sqrt(1 - a));
    }

    final sorted = stopList
        .where((s) => s.Latitude != null && s.Longitude != null && distMeters(s) <= 500)
        .toList()
      ..sort((a, b) => distMeters(a).compareTo(distMeters(b)));

    final static_ = GtfsStaticService();
    final rt = GtfsRealtimeService();
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final List<BothDirectionRouteWithTrips> routeTrips = [];
    final addedRouteDirections = <String>{}; // "routeNo|directionId"

    for (final stop in sorted) {
      final stopId = static_.getStopId(stop.StopNo ?? 0);
      if (stopId == null) continue;

      final realtimeTripIds = <String>{};
      final tripsForStop = <String, List<Trip>>{}; // "routeNo|directionId" -> trips

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

        final key = '$routeNo|${tu.directionId}';
        if (addedRouteDirections.contains(key)) continue;

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

        tripsForStop.putIfAbsent(key, () => []).add(trip);
      }

      // Supplement with scheduled departures.
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

        final key = '$routeNo|${tripInfo.directionId}';
        if (addedRouteDirections.contains(key)) continue;

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

        tripsForStop.putIfAbsent(key, () => []).add(trip);
      }

      // Claim directions from this stop and merge into route tile.
      for (final entry in tripsForStop.entries) {
        addedRouteDirections.add(entry.key);
        final routeNo = entry.key.split('|').first;
        final existing = routeTrips.indexWhere((r) => r.RouteNo == routeNo);
        if (existing < 0) {
          routeTrips.add(BothDirectionRouteWithTrips(routeNo, entry.value));
        } else {
          routeTrips[existing].Trips.addAll(entry.value);
        }
      }
    }

    return routeTrips;
  }
}
