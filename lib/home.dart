// Android build:
// flutter build apk --split-per-abi
// iOS build:
// flutter build ios --release

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemUiOverlayStyle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transitapp/fetchers/BusAtSingleStopFetcher.dart';
import 'package:transitapp/services/GtfsRealtimeService.dart';
import 'package:transitapp/fetchers/LocationFetcher.dart';
import 'package:transitapp/models/Bus.dart';
import 'package:transitapp/util/LifecycleEventHandler.dart';
import 'package:transitapp/util/MarkerHelper.dart';
import 'package:transitapp/util/SunsetHelper.dart';
import 'package:vibration/vibration.dart';

import 'WaitTimesPopup.dart';
import 'bus_sheet.dart';
import 'stop_search_bar.dart';
import 'transit_util.dart';
import 'util/TransitUtil.dart';
import 'fetchers/BusAtStopFetcher.dart';
import 'package:transitapp/services/GtfsStaticService.dart';
import 'fetchers/StopFetcher.dart';
import 'models/BothDirectionRouteWithTrips.dart';
import 'models/Stop.dart';
import 'models/Trip.dart';

///
/// Main stateful widget
///
class TransitApp extends StatefulWidget {
  const TransitApp({super.key});

  @override
  State<TransitApp> createState() => _TransitAppState();
}

///
/// Contains the state of the home screen
///
class _TransitAppState extends State<TransitApp> {
  static const String _MAP_STYLE =
      '[  {    "elementType": "geometry",    "stylers": [      {        "color": "#242f3e"      }    ]  },  {    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#746855"      }    ]  },  {    "elementType": "labels.text.stroke",    "stylers": [      {        "color": "#242f3e"      }    ]  },  {    "featureType": "administrative.locality",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#d59563"      }    ]  },  {    "featureType": "poi",    "stylers": [      {        "visibility": "off"      }    ]  },  {    "featureType": "poi",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#d59563"      }    ]  },  {    "featureType": "poi.park",    "stylers": [      {        "visibility": "on"      }    ]  },  {    "featureType": "poi.park",    "elementType": "geometry",    "stylers": [      {        "color": "#263c3f"      }    ]  },  {    "featureType": "poi.park",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#6b9a76"      }    ]  },  {    "featureType": "road",    "elementType": "geometry",    "stylers": [      {        "color": "#38414e"      }    ]  },  {    "featureType": "road",    "elementType": "geometry.stroke",    "stylers": [      {        "color": "#212a37"      },      {        "visibility": "simplified"      },      {        "weight": 2      }    ]  },  {    "featureType": "road",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#9ca5b3"      }    ]  },  {    "featureType": "road.highway",    "elementType": "geometry",    "stylers": [      {        "color": "#746855"      }    ]  },  {    "featureType": "road.highway",    "elementType": "geometry.stroke",    "stylers": [      {        "color": "#1f2835"      }    ]  },  {    "featureType": "road.highway",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#f3d19c"      }    ]  },  {    "featureType": "transit",    "stylers": [      {        "visibility": "off"      }    ]  },  {    "featureType": "transit",    "elementType": "geometry",    "stylers": [      {        "color": "#2f3948"      }    ]  },  {    "featureType": "transit.station",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#d59563"      }    ]  },  {    "featureType": "water",    "elementType": "geometry",    "stylers": [      {        "color": "#17263c"      }    ]  },  {    "featureType": "water",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#515c6d"      }    ]  },  {    "featureType": "water",    "elementType": "labels.text.stroke",    "stylers": [      {        "color": "#17263c"      }    ]  }]';

  bool darkModeOn = false;
  double _pixelRatio = 1.0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<PolylineId, Polyline> _mapPolylines = {};
  Set<Marker> _routeStopMarkers = {};
  Set<Marker> _stopViewBusMarkers = {};
  Timer? timer;
  Timer? timerShort;
  List<bool> isSelected = [true, false];
  List<BothDirectionRouteWithTrips> nextBuses = [];
  var timeNow = DateTime.now();
  var timeDifference = Duration();
  var timeLastUpdated = DateTime.now();
  DateTime? timeLastUpdatedForInit;
  var isLoading = true;
  var zoomBool = false;
  var highlightedStopNo;
  var listOfStops = <Stop>[];
  var count = 0;
  var scrollsheetText = 'Searching For Buses...';
  var isLocationEnabled = true;
  List<int> scrollSheetDotList = [];
  var tappedIntoStop = false;
  Stop? _tappedStop;
  Position? userLocation;
  List<BothDirectionRouteWithTrips>? nextBusesCopy;
  List<int>? scrollSheetDotListCopy;
  var selectedRouteNo;
  var selectedPattern;
  Marker? selectedStop;

  StreamSubscription<List<ConnectivityResult>>? subscription;
  StreamSubscription<Position>? positionStream;

  bool hasAnimated = false;
  Map<String, Marker> _markers = {};
  bool showingSpecificBuses = false;
  bool hasLoaded = false;

  GoogleMapController? mapController;
  bool isLocationOnMapEnabled = false;
  String? _currentMapStyle;
  final StopSearchBarController _searchBarController = StopSearchBarController();

  void vibrate() async {
    if (await Vibration.hasCustomVibrationsSupport()) {
      Vibration.vibrate(duration: 10);
    }
  }

  Future<Position> getLocation() async {
    if (userLocation != null) {
      return userLocation!;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return Geolocator.getCurrentPosition();
  }

  void initWithLocation() {
    final now = DateTime.now();
    if (timeLastUpdatedForInit == null ||
        now.difference(timeLastUpdatedForInit!).inSeconds > 5) {
      timeLastUpdatedForInit = now;
      getLocation().then((locationData) {
        userLocation = locationData;
        if (!hasAnimated) {
          _currentLocation();
        }
        setState(() {
          isLocationEnabled = true;
        });

        if (isSelected[0]) updateBuses();
        updateNextBusesForAllNearbyStops();
        hasLoaded = true;
      }).catchError((Object onError) {
        hasLoaded = true;
        updateBuses();
        setState(() {
          isLocationEnabled = false;
          scrollsheetText = 'Location Services Disabled';
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      positionStream =
          Geolocator.getPositionStream().listen((Position position) {
        userLocation = position;
      });
    } catch (e) {
      // Permission denied or location service unavailable
    }

    darkModeOn = SunsetHelper.isDark();
    _currentMapStyle = darkModeOn ? _MAP_STYLE : null;

    // Start GTFS static load immediately so it's ready by the time fetchers need it.
    GtfsStaticService().ensureLoaded();

    loadListOfStops().then((stops) {
      listOfStops = stops;

      Connectivity().checkConnectivity().then((connectivityResult) {
        if (connectivityResult == ConnectivityResult.none) {
          setState(() {
            scrollsheetText = 'No Internet Connection';
          });

          subscription =
              Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
            final result = results.isNotEmpty
                ? results.first
                : ConnectivityResult.none;
            if (result != ConnectivityResult.none) {
              initWithLocation();
            } else {
              setState(() {
                scrollsheetText = 'No Internet Connection';
              });
            }
          });
        } else {
          initWithLocation();
        }
      });
    });

    timer = Timer.periodic(
        const Duration(seconds: 30), (Timer t) => timerIfSelectedHelper());
    timerShort = Timer.periodic(
        const Duration(milliseconds: 200), (Timer t) => timerIfSelectedHelperShort());

    WidgetsBinding.instance.addObserver(LifecycleEventHandler(
      resumeCallBack: () async {
        if (hasLoaded) {
          timerIfSelectedHelper();
          timerIfSelectedHelperShort();
          timer = Timer.periodic(const Duration(seconds: 30),
              (Timer t) => timerIfSelectedHelper());
          timerShort = Timer.periodic(const Duration(milliseconds: 200),
              (Timer t) => timerIfSelectedHelperShort());

          darkModeOn = SunsetHelper.isDark();
          _currentMapStyle = darkModeOn ? _MAP_STYLE : null;

          subscription?.resume();
          positionStream?.resume();
          initWithLocation();
        }
      },
      suspendingCallBack: () async {
        if (hasLoaded) {
          timer?.cancel();
          timerShort?.cancel();
          subscription?.pause();
          positionStream?.pause();
        }
      },
    ));
  }

  void timerIfSelectedHelperShort() {
    timeNow = DateTime.now();
    setState(() {
      timeDifference = timeNow.difference(timeLastUpdated);
    });
  }

  Future<List<Stop>> loadListOfStops() async {
    final String stopList = await rootBundle.loadString('assets/stops.txt');
    final List<Stop> stops = [];
    final List<String> lines = stopList.split('\n');
    final List<String> header = lines[0].split(',');
    final int stopNoCol = header.indexOf('stop_code');
    final int nameCol = header.indexOf('stop_name');
    final int longCol = header.indexOf('stop_lon');
    final int latCol = header.indexOf('stop_lat');
    lines.removeAt(0);
    for (final String l in lines) {
      final Stop s = Stop();
      final List<String> paste = l.split(',');
      try {
        s.StopNo = int.parse(paste[stopNoCol]);
      } catch (e) {
        continue;
      }
      s.Name = paste[nameCol];
      s.Longitude = double.parse(paste[longCol]);
      if (paste[nameCol].contains('@')) {
        s.OnStreet = paste[nameCol].split('@')[0];
        s.AtStreet = paste[nameCol].split('@')[1];
      } else {
        s.OnStreet = paste[nameCol];
        s.AtStreet = '';
      }
      s.Latitude = double.parse(paste[latCol]);
      stops.add(s);
    }
    return stops;
  }

  void timerIfSelectedHelper() {
    if (!tappedIntoStop) {
      updateNextBusesForAllNearbyStops();
    }
    timeLastUpdated = DateTime.now();
    if (isSelected[0] == true) {
      updateBuses();
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    positionStream?.cancel();
    timer?.cancel();
    timerShort?.cancel();
    super.dispose();
  }

  Future<List<Marker>> getBusList(List<Bus> buses) async {
    final List<Marker> l = [];
    final ui.Image image = await load('images/bus-icon-outline.png');

    final List<Future<BitmapDescriptor>> bitmapFutures = [
      for (final Bus bus in buses)
        MarkerHelper.createCustomMarkerBitmap(bus.RouteNo ?? '', buses.indexOf(bus), image, pixelRatio: _pixelRatio),
    ];

    final List<BitmapDescriptor> descriptors =
        await Future.wait(bitmapFutures);

    for (int i = 0; i < buses.length; i++) {
      final Bus bus = buses[i];
      final marker = Marker(
        onTap: () => _onBusMarkerTap(bus.RouteNo ?? '', bus.TripId?.toString()),
        markerId: MarkerId(
            '${bus.VehicleNo?.isNotEmpty == true ? bus.VehicleNo : i}!${bus.RouteNo}!${bus.Pattern}'),
        position: LatLng(
            (bus.Latitude ?? 0) - 0.00005, bus.Longitude ?? 0),
        infoWindow: InfoWindow(
          title: () {
            final dest = bus.Destination ?? '';
            final toIdx = dest.toLowerCase().indexOf('/to ');
            return toIdx != -1 ? dest.substring(toIdx + 4).trim() : dest;
          }(),
        ),
        icon: descriptors[i],
      );
      l.add(marker);
    }
    return l;
  }

  void _onBusMarkerTap(String routeNo, String? tripId) {
    setState(() {
      _mapPolylines.clear();
      _routeStopMarkers = {};
    });
    final color = GtfsStaticService().getRouteColor(routeNo, isDark: darkModeOn);
    final tripShape = tripId != null ? GtfsStaticService().getShapeForTrip(tripId) : null;
    if (tripShape != null) {
      addLines(routeNo, tripShape, 0, color);
    } else {
      final shapes = GtfsStaticService().getShapesForRoute(routeNo);
      for (int i = 0; i < shapes.length; i++) {
        addLines(routeNo, shapes[i], i, color);
      }
    }
    if (tripId != null) {
      final stops = GtfsStaticService().getStopsForTrip(tripId);
      if (stops.isNotEmpty) {
        MarkerHelper.createDotMarker(size: 10, pixelRatio: _pixelRatio).then((dotIcon) {
          final markers = <Marker>{};
          for (final stop in stops) {
            if (stop.Latitude == null || stop.Longitude == null) continue;
            final snapped = tripShape != null
                ? _snapToPolyline(LatLng(stop.Latitude!, stop.Longitude!), tripShape)
                : LatLng(stop.Latitude!, stop.Longitude!);
            markers.add(Marker(
              markerId: MarkerId('routestop_${stop.StopNo}'),
              position: snapped,
              icon: dotIcon,
              anchor: const Offset(0.5, 0.5),
            ));
          }
          setState(() { _routeStopMarkers = markers; });
        });
      }
    }
  }

  /// Returns the closest point on [polyline] to [point].
  LatLng _snapToPolyline(LatLng point, List<LatLng> polyline) {
    double bestDist = double.infinity;
    LatLng best = polyline.first;
    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final ax = a.longitude, ay = a.latitude;
      final bx = b.longitude, by = b.latitude;
      final px = point.longitude, py = point.latitude;
      final dx = bx - ax, dy = by - ay;
      final lenSq = dx * dx + dy * dy;
      double t = lenSq == 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / lenSq;
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * dx, cy = ay + t * dy;
      final d = (px - cx) * (px - cx) + (py - cy) * (py - cy);
      if (d < bestDist) {
        bestDist = d;
        best = LatLng(cy, cx);
      }
    }
    return best;
  }

  void addLines(String routeNum, List<LatLng> listofLatLng, int index, Color color) {
    final PolylineId polylineId = PolylineId(index.toString());
    setState(() {
      _mapPolylines[polylineId] = Polyline(
        polylineId: polylineId,
        consumeTapEvents: true,
        color: color,
        width: 8,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        points: listofLatLng,
      );
    });
  }

  Future<List<Stop>> search(String searchText) async {
    final List<Stop> toRet = [];
    for (final Stop s in listOfStops) {
      if ((s.Name?.toLowerCase().contains(searchText.toLowerCase()) ?? false) ||
          s.StopNo.toString().contains(searchText)) {
        final Stop newStop = Stop()
          ..StopNo = s.StopNo
          ..Name = s.Name
          ..OnStreet = s.OnStreet
          ..AtStreet = s.AtStreet
          ..Longitude = s.Longitude
          ..Latitude = s.Latitude;
        toRet.add(newStop);
        if (toRet.length > 20) break;
      }
    }
    return toRet;
  }

  Future<List<Marker>> getStopList(List<Stop> stops) async {
    final List<Marker> l = [];
    final ui.Image image = await load('images/StopIcon.png');

    final List<Future<BitmapDescriptor>> bitmapFutures = [
      for (final Stop stop in stops)
        MarkerHelper.createCustomMarkerBitmapNoText(
          image,
          highlightedStopNo == stop.StopNo ? 60 : 38,
          highlightedStopNo == stop.StopNo ? 60 : 38,
          pixelRatio: _pixelRatio,
        ),
    ];

    final List<BitmapDescriptor> descriptors =
        await Future.wait(bitmapFutures);

    for (int i = 0; i < stops.length; i++) {
      final Stop stop = stops[i];
      final marker = Marker(
        onTap: () => _onStopTapped(stop),
        markerId: MarkerId(stop.StopNo.toString()),
        position: LatLng(stop.Latitude ?? 0, stop.Longitude ?? 0),
        infoWindow: InfoWindow(
          title: stop.Name.toString(),
          snippet: stop.StopNo.toString(),
        ),
        icon: descriptors[i],
      );
      l.add(marker);
    }
    return l;
  }

  void _onStopTapped(Stop stop) {
    setState(() {
      if (!tappedIntoStop) {
        nextBusesCopy = List<BothDirectionRouteWithTrips>.from(nextBuses);
        scrollSheetDotListCopy = List<int>.from(scrollSheetDotList);
      }
      tappedIntoStop = true;
      _tappedStop = stop;
      count = 2;
      BusAtSingleStopFetcher()
          .busAtSingleStopFetcher(stop, stop.StopNo.toString())
          .then((List<BothDirectionRouteWithTrips> value) {
        renderListOfNextBuses(value);
      });
    });
    if (stop.StopNo != null) _loadStopViewBusMarkers(stop.StopNo!);
  }

  void _refreshTappedStop() {
    final stop = _tappedStop;
    if (stop == null) return;
    setState(() { isLoading = true; });
    BusAtSingleStopFetcher()
        .busAtSingleStopFetcher(stop, stop.StopNo.toString())
        .then((value) {
      renderListOfNextBuses(value);
      setState(() { isLoading = false; });
    });
  }


  Future<void> _loadStopViewBusMarkers(int stopCode) async {
    await GtfsStaticService().ensureLoaded();
    final static_ = GtfsStaticService();
    final internalStopId = static_.getStopId(stopCode);
    if (internalStopId == null) return;

    final routeIds = static_.getRouteIdsServingStop(internalStopId);

    final allPositions = await GtfsRealtimeService().getVehiclePositions();
    final matching = allPositions.where((v) {
      final routeId = v.routeId.isNotEmpty
          ? v.routeId
          : (static_.getTripInfo(v.tripId)?.routeId ?? '');
      if (routeIds.contains(routeId)) return true;
      // Fallback: check directly if the vehicle's trip visits this stop
      return static_.doesTripServeStop(v.tripId, internalStopId);
    }).toList();

    if (matching.isEmpty) return;

    final image = await load('images/bus-icon-outline.png');
    final bitmapFutures = <Future<BitmapDescriptor>>[];
    for (final v in matching) {
      final routeId = v.routeId.isNotEmpty
          ? v.routeId
          : (static_.getTripInfo(v.tripId)?.routeId ?? '');
      String routeShort = removeZeroes(static_.getRouteShortName(routeId) ?? routeId);
      bitmapFutures.add(MarkerHelper.createCustomMarkerBitmap(
        routeShort, 0, image, pixelRatio: _pixelRatio));
    }
    final descriptors = await Future.wait(bitmapFutures);

    final markers = <Marker>{};
    for (int i = 0; i < matching.length; i++) {
      final v = matching[i];
      final routeId = v.routeId.isNotEmpty ? v.routeId : (static_.getTripInfo(v.tripId)?.routeId ?? '');
      final routeNo = removeZeroes(static_.getRouteShortName(routeId) ?? routeId);
      markers.add(Marker(
        markerId: MarkerId('stopview_${v.vehicleId}'),
        position: LatLng(v.latitude - 0.00005, v.longitude),
        icon: descriptors[i],
        onTap: () => _onBusMarkerTap(routeNo, v.tripId),
      ));
    }
    if (mounted) setState(() { _stopViewBusMarkers = markers; });
  }

  void updateNextBusesForAllNearbyStops() async {
    setState(() { isLoading = true; });
    Position locationData;
    try {
      locationData = await getLocation();
      setState(() {
        isLocationEnabled = true;
        scrollsheetText = 'Searching For Buses...';
      });
    } catch (e) {
      setState(() {
        isLocationEnabled = false;
        isLoading = false;
        scrollsheetText = 'Location Services Disabled';
      });
      return;
    }

    final List<BothDirectionRouteWithTrips> buses =
        await BusAtStopFetcher().busFetcher(
      listOfStops,
      locationData.latitude,
      locationData.longitude,
    );
    renderListOfNextBuses(buses);
    setState(() {
      isLocationEnabled = true;
      isLoading = false;
    });
  }

  void renderListOfNextBuses(List<BothDirectionRouteWithTrips> buses) {
    scrollSheetDotList.clear();
    nextBuses.clear();
    if (buses.isEmpty) {
      setState(() {
        scrollsheetText = 'No Buses Found';
      });
      return;
    }
    for (final BothDirectionRouteWithTrips b in buses) {
      final List<dynamic> directions = [];
      final Map<String, Trip> destinationToTrip = HashMap();
      for (final Trip t in b.Trips) {
        final String pattern = patternHelper(t.Pattern ?? '');
        if (destinationToTrip.containsKey(pattern)) {
          if ((t.ExpectedCountdown ?? 0) <
              (destinationToTrip[pattern]!.ExpectedCountdown ?? 0)) {
            destinationToTrip[pattern] = t;
          }
        } else {
          destinationToTrip[pattern] = t;
          directions.add(pattern);
        }
      }
      final BothDirectionRouteWithTrips bitrip =
          BothDirectionRouteWithTrips('', []);
      bitrip.RouteNo = b.RouteNo;
      for (final dynamic s in directions) {
        destinationToTrip[s]!.RouteNo = b.RouteNo;
        bitrip.Trips.add(destinationToTrip[s]!);
      }
      setState(() {
        nextBuses.add(bitrip);
        scrollSheetDotList.add(0);
      });
    }
  }

  void updateBuses() async {
    setState(() { isLoading = true; });
    try {
      final List<Bus> buses = await LocationFetcher().fetchAllBuses();
      final List<Marker> list = await getBusList(buses);
      setState(() {
        isLoading = false;
        _markers.clear();
        for (final Marker m in list) {
          _markers[m.markerId.toString()] = m;
        }
      });
    } catch (_) {
      setState(() { isLoading = false; });
    }
  }

  void getLocationAndUpdateStops() async {
    Position locationData;
    try {
      locationData = await getLocation();
      setState(() {
        isLocationEnabled = true;
        scrollsheetText = 'Searching For Buses...';
      });
    } catch (e) {
      setState(() {
        isLocationEnabled = false;
        scrollsheetText = 'Location Services Disabled';
      });
      return;
    }
    if (zoomBool == true) {
      updateStops(
        locationData.latitude.toString(),
        locationData.longitude.toString(),
      );
    }
  }

  void _applyMarkerDiff(List<Marker> newList) {
    final newMap = {for (final m in newList) m.markerId.toString(): m};
    _markers.removeWhere((id, _) => !newMap.containsKey(id));
    for (final entry in newMap.entries) {
      _markers[entry.key] = entry.value;
    }
  }

  void updateStops(String latitude, String longitude) async {
    final List<Stop> stops =
        await StopFetcher().stopFetcher(latitude, longitude);
    final List<Marker> list = await getStopList(stops);
    if (!mounted) return;
    setState(() => _applyMarkerDiff(list));
  }

  void updateStopsForMap(double latitude1, double latitude2,
      double longitude1, double longitude2) async {
    final List<Stop> validStops = [
      for (final Stop s in listOfStops)
        if ((s.Latitude ?? 0) < latitude1 &&
            (s.Latitude ?? 0) > latitude2 &&
            (s.Longitude ?? 0) < longitude1 &&
            (s.Longitude ?? 0) > longitude2)
          s,
    ];
    final List<Marker> list = await getStopList(validStops);
    if (!mounted) return;
    setState(() => _applyMarkerDiff(list));
  }

  Future<ui.Image> load(String asset) async {
    final ByteData data = await rootBundle.load(asset);
    final ui.Codec codec =
        await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    _currentLocation();
  }

  Future<void> openWaitTimesPopup(
      String routeNo, String pattern, String stopNo) async {
    final BuildContext? ctx = _scaffoldKey.currentContext;
    if (ctx == null) return;
    await Navigator.of(ctx).push(MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return WaitTimesPopup(
          routeNo: removeZeroes(routeNo),
          pattern: patternHelper(pattern),
          stopNo: stopNo,
          isDarkMode: darkModeOn,
        );
      },
      fullscreenDialog: true,
    ));
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _currentLocation() async {
    if (mapController == null) return;
    try {
      final position = await Geolocator.getCurrentPosition();
      userLocation = position;
      setState(() {
        isLocationEnabled = true;
        isLocationOnMapEnabled = true;
      });
      hasAnimated = true;
      mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          bearing: 0,
          target: LatLng(position.latitude, position.longitude),
          zoom: 16.0,
        ),
      ));
    } on Exception {
      setState(() {
        isLocationEnabled = false;
        scrollsheetText = 'Location Services Disabled';
      });
      userLocation = null;
    }
  }

  ///
  /// Builds the UI
  ///
  @override
  Widget build(BuildContext context) {
    _pixelRatio = MediaQuery.of(context).devicePixelRatio;
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: darkModeOn ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(171, 171, 171, 1),
            primary: const Color.fromRGBO(171, 171, 171, 1),
          ),
        ),
        home: Scaffold(
          key: _scaffoldKey,
          resizeToAvoidBottomInset: false,
          backgroundColor: darkModeOn ? colorFromHex('1b2336') : Colors.white,
          body: Stack(children: <Widget>[
            GoogleMap(
              myLocationEnabled: isLocationOnMapEnabled,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              style: _currentMapStyle,
              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(
                target: LatLng(49.2418584, -123.1401792),
                zoom: 14,
              ),
              polylines: Set<Polyline>.of(_mapPolylines.values),
              markers: _markers.values
                  .where((marker) {
                    if (tappedIntoStop && isSelected[1]) {
                      return marker.markerId.value == _tappedStop?.StopNo.toString();
                    }
                    if (selectedRouteNo == null || selectedPattern == null) {
                      return true;
                    }
                    final parts = marker.markerId.value.split('!');
                    if (parts.length < 3) return false;
                    return parts[1] == removeZeroes(selectedRouteNo) &&
                        parts[2].startsWith(
                            (selectedPattern as String).substring(0, 1));
                  })
                  .toSet()
                  .union(Set.from(selectedStop == null ? [] : [selectedStop]))
                  .union(_routeStopMarkers)
                  .union(_stopViewBusMarkers),
              onTap: (LatLng a) {
                tappedIntoStop = false;
                _searchBarController.clear();
                setState(() {
                  highlightedStopNo = null;
                  if (nextBusesCopy != null &&
                      scrollSheetDotListCopy != null) {
                    nextBuses = nextBusesCopy!;
                    scrollSheetDotList = scrollSheetDotListCopy!;
                  }
                  _mapPolylines.clear();
                  _routeStopMarkers = {};
                  _stopViewBusMarkers = {};
                });
                if (isSelected[0] == false) {
                  showZoomInIfNeeded();
                }
              },
              onCameraIdle: () {
                count--;
                if (count <= 0) {
                  if (!tappedIntoStop) {
                    highlightedStopNo = null;
                    setState(() {
                      if (nextBusesCopy != null &&
                          scrollSheetDotListCopy != null) {
                        nextBuses = nextBusesCopy!;
                        scrollSheetDotList = scrollSheetDotListCopy!;
                      }
                    });
                  }
                  if (isSelected[0] == false && !tappedIntoStop) {
                    showZoomInIfNeeded();
                  }
                  if (tappedIntoStop && _tappedStop?.StopNo != null) {
                    mapController?.showMarkerInfoWindow(
                        MarkerId(_tappedStop!.StopNo.toString()));
                  }
                }
              },
            ),
            AnimatedOpacity(
              opacity: zoomBool ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 681),
              child: Align(
                alignment: Alignment.center,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: darkModeOn
                          ? Colors.white70
                          : Colors.black54,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.normal,
                      fontSize: 18,
                    ),
                    text: 'Zoom in to see stops',
                  ),
                ),
              ),
            ),
            Visibility(
              visible: !showingSpecificBuses,
              child: Positioned(
                top: 116,
                right: 7,
                child: SizedBox(
                  height: 50,
                  width: 50,
                  child: FittedBox(
                    child: FloatingActionButton(
                      heroTag: 'toggleMode',
                      shape: const CircleBorder(),
                      elevation: 1,
                      onPressed: () {
                        vibrate();
                        final bool switchingToStops = isSelected[0];
                        if (nextBusesCopy != null && scrollSheetDotListCopy != null) {
                          nextBuses = nextBusesCopy!;
                          scrollSheetDotList = scrollSheetDotListCopy!;
                        }
                        if (switchingToStops) {
                          _mapPolylines.clear();
                          _routeStopMarkers = {};
                          showZoomInIfNeeded();
                          getLocationAndUpdateStops();
                        } else {
                          updateBuses();
                          setState(() { zoomBool = false; });
                        }
                        setState(() {
                          isSelected = switchingToStops ? [false, true] : [true, false];
                          tappedIntoStop = false;
                          _stopViewBusMarkers = {};
                        });
                      },
                      backgroundColor: darkModeOn
                          ? const Color.fromRGBO(50, 52, 58, 1)
                          : const Color.fromRGBO(255, 255, 255, 0.95),
                      child: Icon(
                        isSelected[0] ? Icons.directions_bus : Icons.pin_drop,
                        size: 24,
                        color: darkModeOn
                            ? Colors.white70
                            : getColorFromHex('10295D'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: !showingSpecificBuses,
              child: BusSheet(
                nextBuses: nextBuses,
                dotList: scrollSheetDotList,
                darkModeOn: darkModeOn,
                emptyText: scrollsheetText,
                isLocationEnabled: isLocationEnabled,
                tappedIntoStop: tappedIntoStop,
                isLoading: isLoading,
                timeDifference: timeDifference,
                onRefresh: () {
                  GtfsRealtimeService().invalidateCache();
                  timeLastUpdated = DateTime.now();
                  if (tappedIntoStop) {
                    _refreshTappedStop();
                  } else {
                    updateNextBusesForAllNearbyStops();
                    if (isSelected[0]) updateBuses();
                  }
                },
                onCenterLocation: _currentLocation,
                onTripTap: openWaitTimesPopup,
                onDotChanged: (routeIndex, dot) {
                  setState(() {
                    scrollSheetDotList[routeIndex] = dot;
                  });
                },
              ),
            ),
            Visibility(
              visible: !showingSpecificBuses,
              child: StopSearchBar(
                controller: _searchBarController,
                hintText: 'Search for stops',
                padding: const EdgeInsets.fromLTRB(10, 60, 10, 0),
                onSearch: search,
                onCancelled: () {
                  setState(() {
                    highlightedStopNo = null;
                  });
                },
                emptyWidget: const Text(
                  'No Stops Found',
                  style: TextStyle(fontSize: 18),
                ),
                onItemFound: (Stop post, int index) {
                  return ListTile(
                    title: Text(post.StopNo.toString()),
                    subtitle: Text(post.Name ?? ''),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _onStopTapped(post);
                      _searchBarController.clear();
                      highlightedStopNo = post.StopNo;
                      updateStops(
                          (post.Latitude ?? 0).toString(),
                          (post.Longitude ?? 0).toString());
                      mapController?.animateCamera(
                          CameraUpdate.newCameraPosition(CameraPosition(
                              target: LatLng(post.Latitude ?? 0, post.Longitude ?? 0),
                              zoom: 18)));
                    },
                  );
                },
              ),
            ),
            Visibility(
              visible: showingSpecificBuses,
              child: Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    height: 70,
                    width: 70,
                    child: FittedBox(
                      child: FloatingActionButton(
                        heroTag: 'mcdonalds',
                        onPressed: () {
                          setState(() {
                            showingSpecificBuses = false;
                            selectedRouteNo = null;
                            selectedStop = null;
                            selectedPattern = null;
                          });
                        },
                        backgroundColor:
                            const ui.Color.fromARGB(64, 165, 8, 8),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          size: 25,
                          color: ui.Color.fromRGBO(174, 19, 19, 0.851),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void showZoomInIfNeeded() {
    mapController?.getZoomLevel().then((value) {
      if (value >= 14) {
        setState(() {
          zoomBool = false;
        });
        mapController?.getVisibleRegion().then((value) {
          updateStopsForMap(
            value.northeast.latitude,
            value.southwest.latitude,
            value.northeast.longitude,
            value.southwest.longitude,
          );
        });
      } else {
        setState(() {
          _markers.clear();
          zoomBool = true;
        });
      }
    });
  }

  void filterBuses(String routeNo, String pattern, String stopNo) {
    if (isSelected[1]) {
      setState(() {
        isSelected[0] = true;
        isSelected[1] = false;
      });
      updateBuses();
    }
    load('images/StopIcon.png').then((image) {
      MarkerHelper.createCustomMarkerBitmapNoText(image, 56, 56, pixelRatio: _pixelRatio)
          .then((bitmapDescriptor) {
        double? latitude;
        double? longitude;
        String? stopName;
        for (final Stop s in listOfStops) {
          if (s.StopNo.toString() == stopNo) {
            latitude = s.Latitude;
            longitude = s.Longitude;
            stopName = s.Name;
            break;
          }
        }
        if (stopName == null || latitude == null || longitude == null) return;
        final marker = Marker(
          markerId: MarkerId(stopNo),
          position: LatLng(latitude, longitude),
          infoWindow: InfoWindow(
            title: stopName,
            snippet: stopNo,
          ),
          icon: bitmapDescriptor,
        );
        setState(() {
          selectedPattern = pattern;
          selectedRouteNo = routeNo;
          selectedStop = marker;
        });
      });
    });
  }
}



