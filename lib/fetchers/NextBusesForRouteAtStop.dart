import 'package:transitapp/models/Trip.dart';
import 'package:transitapp/services/GtfsRealtimeService.dart';
import 'package:transitapp/services/GtfsStaticService.dart';
import 'package:transitapp/transit_util.dart';
import 'package:transitapp/util/GtfsUtil.dart';

class NextBusesForRouteAtStop {
  Future<List<Trip>> busAtSingleStopFetcher(
      String stopNo, String routeNo, String pattern) async {
    await GtfsStaticService().ensureLoaded();

    final stopCode = int.tryParse(stopNo);
    if (stopCode == null) return [];
    final static_ = GtfsStaticService();
    final stopId = static_.getStopId(stopCode);
    if (stopId == null) return [];
    final stop = static_.getStopByCode(stopCode);

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final trips = <Trip>[];
    final realtimeTripIds = <String>{};

    bool matchesPattern(int directionId) {
      if (stop == null) return true;
      return patternHelper(GtfsUtil.directionFromStop(stop.OnStreet, directionId)) == pattern;
    }

    // Realtime entries — try internal stop ID first, fall back to stop code string
    // (some feeds index by stop code rather than internal ID)
    var entries = await GtfsRealtimeService().getDeparturesForStop(stopId);
    if (entries.isEmpty) {
      entries = await GtfsRealtimeService().getDeparturesForStop(stopNo);
    }
    for (final entry in entries) {
      final tu = entry.tripUpdate;
      final stu = entry.stopTimeUpdate;

      final tripInfo = static_.getTripInfo(tu.tripId);
      final routeId = tu.routeId.isNotEmpty ? tu.routeId : (tripInfo?.routeId ?? '');
      String thisRouteNo = static_.getRouteShortName(routeId) ?? routeId;
      while (thisRouteNo.startsWith('0')) thisRouteNo = thisRouteNo.substring(1);
      if (thisRouteNo != routeNo) continue;
      if (!matchesPattern(tu.directionId)) continue;

      int? departureTime = stu.time;
      if (departureTime == null && stu.delay != null) {
        final scheduled = static_.getScheduledEpoch(tu.tripId, stu.stopId);
        if (scheduled != null) departureTime = scheduled + stu.delay!;
      }
      if (departureTime == null) continue;
      final countdown = ((departureTime - nowSec) / 60).floor();
      if (countdown < 0) continue;

      realtimeTripIds.add(tu.tripId);
      trips.add(Trip(
        Pattern: GtfsUtil.directionFromStop(stop?.OnStreet, tu.directionId),
        Destination: GtfsUtil.stripHeadsignPrefix(tripInfo?.headsign ?? '').toUpperCase(),
        ExpectedCountdown: countdown,
        LastUpdate: DateTime.now().toIso8601String(),
        RouteNo: thisRouteNo,
        ExpectedLeaveTime: GtfsUtil.formatTime(departureTime),
      )..tripId = tu.tripId);
    }

    // Scheduled departures for trips not already in the realtime feed
    final scheduled = static_.getScheduledDepartures(stopId);
    for (final (tripId, epochSec) in scheduled) {
      if (realtimeTripIds.contains(tripId)) continue;

      final tripInfo = static_.getTripInfo(tripId);
      if (tripInfo == null) continue;

      String thisRouteNo = static_.getRouteShortName(tripInfo.routeId) ?? tripInfo.routeId;
      while (thisRouteNo.startsWith('0')) thisRouteNo = thisRouteNo.substring(1);
      if (thisRouteNo != routeNo) continue;
      if (!matchesPattern(tripInfo.directionId)) continue;

      final (:cancelled, :delay) = await GtfsRealtimeService().getTripStatus(tripId);
      if (cancelled) continue;
      final rtDelay = delay;
      final actualEpoch = rtDelay != null ? epochSec + rtDelay : epochSec;

      final countdown = ((actualEpoch - nowSec) / 60).floor();
      if (countdown < 0) continue;

      trips.add(Trip(
        Pattern: GtfsUtil.directionFromStop(stop?.OnStreet, tripInfo.directionId),
        Destination: GtfsUtil.stripHeadsignPrefix(tripInfo.headsign).toUpperCase(),
        ExpectedCountdown: countdown,
        LastUpdate: rtDelay != null ? DateTime.now().toIso8601String() : null,
        RouteNo: thisRouteNo,
        ExpectedLeaveTime: GtfsUtil.formatTime(actualEpoch),
      )..tripId = tripId);
    }

    trips.sort((a, b) => (a.ExpectedCountdown ?? 0).compareTo(b.ExpectedCountdown ?? 0));
    return trips;
  }
}
