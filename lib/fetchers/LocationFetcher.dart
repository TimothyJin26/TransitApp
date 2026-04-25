import 'package:flutter/foundation.dart';
import 'package:transitapp/models/Bus.dart';
import 'package:transitapp/models/RouteLink.dart';
import 'package:transitapp/services/GtfsRealtimeService.dart';
import 'package:transitapp/services/GtfsStaticService.dart';

class LocationFetcher {
  /// Fetches the locations of all active buses from the GTFS RT position feed.
  Future<List<Bus>> fetchAllBuses() async {
    await GtfsStaticService().ensureLoaded();

    final vehicles = await GtfsRealtimeService().getVehiclePositions();
    final static_ = GtfsStaticService();
    final bool routesLoaded = static_.hasRoutesLoaded;
    if (!routesLoaded) {
      debugPrint('LocationFetcher: GTFS static routes not loaded — bus markers will show raw route_id');
    }
    final List<Bus> buses = [];

    for (final v in vehicles) {
      final tripInfo = static_.getTripInfo(v.tripId);
      final routeId =
          v.routeId.isNotEmpty ? v.routeId : (tripInfo?.routeId ?? '');
      String routeNo = static_.getRouteShortName(routeId) ?? routeId;
      if (!routesLoaded && buses.isEmpty && routeId.isNotEmpty) {
        debugPrint('LocationFetcher: sample routeId="$routeId" tripId="${v.tripId}" vehicleId="${v.vehicleId}"');
      }
      if (routesLoaded && static_.getRouteShortName(routeId) == null && routeId.isNotEmpty) {
        debugPrint('LocationFetcher: no route name for routeId="$routeId" tripId="${v.tripId}"');
      }
      while (routeNo.startsWith('0')) {
        routeNo = routeNo.substring(1);
      }

      final destination = (tripInfo?.headsign ?? '').toUpperCase();
      final directionId = tripInfo?.directionId ?? 0;
      final direction = _bearingToDirection(v.bearing) ??
          (directionId == 0 ? 'OUTBOUND' : 'INBOUND');

      // Reconstruct KMZ URL so route polylines keep working.
      final kmzUrl = _buildKmzUrl(routeNo);

      buses.add(Bus(
        VehicleNo: v.vehicleId,
        TripId: int.tryParse(v.tripId),
        RouteNo: routeNo,
        Direction: direction,
        Destination: destination,
        Pattern: '${direction[0]}B1',
        Latitude: v.latitude,
        Longitude: v.longitude,
        RecordedTime: DateTime.now().toString(),
        RouteMap: RouteLink(Href: kmzUrl),
      ));
    }

    return buses;
  }

  static String? _bearingToDirection(double? bearing) {
    if (bearing == null) return null;
    final b = bearing % 360;
    if (b < 45 || b >= 315) return 'NORTH';
    if (b < 135) return 'EAST';
    if (b < 225) return 'SOUTH';
    return 'WEST';
  }

  static String _buildKmzUrl(String routeNo) {
    final num = int.tryParse(routeNo);
    if (num != null) {
      return 'https://nb.translink.ca/geodata/${routeNo.padLeft(3, '0')}.kmz';
    }
    return 'https://nb.translink.ca/geodata/$routeNo.kmz';
  }
}
