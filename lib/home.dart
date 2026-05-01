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
import 'package:transitapp/proto/GtfsRealtimeReader.dart';
import 'package:transitapp/services/GtfsRealtimeService.dart';
import 'package:transitapp/fetchers/LocationFetcher.dart';
import 'package:transitapp/models/Bus.dart';
import 'package:transitapp/util/GtfsUtil.dart';
import 'package:transitapp/util/LifecycleEventHandler.dart';
import 'package:transitapp/util/MarkerHelper.dart';
import 'package:transitapp/util/SunsetHelper.dart';
import 'package:vibration/vibration.dart';

import 'bus_sheet.dart';
import 'fetchers/NextBusesForRouteAtStop.dart';
import 'wait_times_sheet.dart';
import 'stop_search_bar.dart';
import 'transit_util.dart';
import 'util/TransitUtil.dart';
import 'fetchers/BusAtStopFetcher.dart';
import 'package:transitapp/services/GtfsStaticService.dart';
import 'fetchers/StopFetcher.dart';
import 'models/BothDirectionRouteWithTrips.dart';
import 'models/Stop.dart';
import 'models/Trip.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _mapReady = false;
  bool _showWaitTimes = false;
  String _wtRouteNo = '';
  List<Trip> _wtTrips = [];
  bool _wtLoading = false;
  Marker? _wtStopMarker;
  final _waitTimesKey = GlobalKey<WaitTimesSheetState>();
  List<(GtfsVehiclePosition, String)> _wtBusEntries = []; // (vehicle, routeShort)
  int _wtDirectionId = 0;
  Timer? _wtAgeTimer;
  ui.Image? _busIconImage;
  LatLng? _overlayLatLng;
  ScreenCoordinate? _overlayCoord;
  String? _overlayTitle;
  String? _overlaySubtitle;
  DateTime? _overlayBusLastSeen;
  Timer? _overlayTimer;
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

  Future<void> _loadSavedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final onStops = prefs.getBool('tab_stops') ?? false;
    if (onStops && mounted) {
      setState(() => isSelected = [false, true]);
      getLocationAndUpdateStops();
    }
  }

  Future<void> _saveTab() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tab_stops', isSelected[1]);
  }

  @override
  void initState() {
    super.initState();
    _loadSavedTab();
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
    GtfsStaticService().invalidateCache().then((_) => GtfsStaticService().ensureLoaded());

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
    _overlayTimer?.cancel();
    super.dispose();
  }

  static String? _ageLabel(DateTime? lastSeen) {
    if (lastSeen == null) return null;
    final secs = DateTime.now().difference(lastSeen).inSeconds;
    if (secs <= 20) return null;
    if (secs < 60) return '$secs';
    return '${(secs / 60).floor()}m';
  }

  Future<List<Marker>> getBusList(List<Bus> buses) async {
    final List<Marker> l = [];
    final ui.Image image = await load('images/bus-icon-outline.png');

    final List<Future<BitmapDescriptor>> bitmapFutures = [
      for (final Bus bus in buses)
        MarkerHelper.createCustomMarkerBitmap(bus.RouteNo ?? '', buses.indexOf(bus), image,
            pixelRatio: _pixelRatio),
    ];

    final List<BitmapDescriptor> descriptors =
        await Future.wait(bitmapFutures);

    for (int i = 0; i < buses.length; i++) {
      final Bus bus = buses[i];
      final marker = Marker(
        onTap: () async {
          _onBusMarkerTap(bus.RouteNo ?? '', bus.TripId?.toString());
          final dest = bus.Destination ?? '';
          final toIdx = dest.toLowerCase().indexOf('/to ');
          final cleanDest = toIdx != -1 ? dest.substring(toIdx + 4).trim() : dest;
          final pos = LatLng((bus.Latitude ?? 0) - 0.00005, bus.Longitude ?? 0);
          final positions = await GtfsRealtimeService().getVehiclePositions();
          final match = positions.where((v) => v.tripId == bus.TripId?.toString()).firstOrNull;
          await _showMarkerOverlay(position: pos, title: cleanDest.isNotEmpty ? cleanDest : null, lastSeen: match?.lastSeen);
        },
        markerId: MarkerId(
            '${bus.VehicleNo?.isNotEmpty == true ? bus.VehicleNo : i}!${bus.RouteNo}!${bus.Pattern}'),
        position: LatLng(
            (bus.Latitude ?? 0) - 0.00005, bus.Longitude ?? 0),
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
          38,
          38,
          pixelRatio: _pixelRatio,
        ),
    ];

    final List<BitmapDescriptor> descriptors =
        await Future.wait(bitmapFutures);

    for (int i = 0; i < stops.length; i++) {
      final Stop stop = stops[i];
      final marker = Marker(
        onTap: () {
          _onStopTapped(stop);
          _showMarkerOverlay(
            position: LatLng(stop.Latitude ?? 0, stop.Longitude ?? 0),
            title: stop.Name.toString(),
            subtitle: stop.StopNo.toString(),
          );
        },
        markerId: MarkerId(stop.StopNo.toString()),
        position: LatLng(stop.Latitude ?? 0, stop.Longitude ?? 0),
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
        onTap: () async {
          _onBusMarkerTap(routeNo, v.tripId);
          final dest = static_.getTripInfo(v.tripId)?.headsign ?? '';
          final pos = LatLng(v.latitude - 0.00005, v.longitude);
          await _showMarkerOverlay(position: pos, title: dest.isNotEmpty ? dest : null, lastSeen: v.lastSeen);
        },
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

  Future<void> _openWaitTimes(
      String routeNo, String pattern, String stopNo) async {
    FocusScope.of(context).unfocus();
    final cleanRoute = removeZeroes(routeNo);
    final cleanPattern = patternHelper(pattern);
    setState(() {
      _showWaitTimes = true;
      _wtRouteNo = cleanRoute;
      _wtLoading = true;
      _wtTrips = [];
    });
    final trips = await NextBusesForRouteAtStop()
        .busAtSingleStopFetcher(stopNo, cleanRoute, cleanPattern);
    if (!mounted) return;
    setState(() {
      _wtTrips = trips;
      _wtLoading = false;
    });
    _loadWaitTimesMapData(
      cleanRoute, pattern, stopNo,
      tripId: trips.isNotEmpty ? trips.first.tripId : null,
    );
    _buildWtStopMarker(stopNo);
  }

  Future<void> _buildWtStopMarker(String stopNo) async {
    final stopCode = int.tryParse(stopNo);
    if (stopCode == null) return;
    Stop? stop;
    for (final s in listOfStops) {
      if (s.StopNo == stopCode) { stop = s; break; }
    }
    if (stop == null || stop.Latitude == null || stop.Longitude == null) return;
    final image = await load('images/StopIcon.png');
    final icon = await MarkerHelper.createCustomMarkerBitmapNoText(
        image, 38, 38, pixelRatio: _pixelRatio);
    if (!mounted) return;
    setState(() {
      _wtStopMarker = Marker(
        markerId: MarkerId('wt_stop_$stopNo'),
        position: LatLng(stop!.Latitude!, stop.Longitude!),
        icon: icon,
      );
    });
  }

  void _dismissWaitTimes() {
    final sheetState = _waitTimesKey.currentState;
    if (sheetState != null) {
      sheetState.dismiss();
    } else {
      _clearWaitTimesState();
    }
  }

  void _clearWaitTimesState() {
    _wtAgeTimer?.cancel();
    _wtAgeTimer = null;
    _wtBusEntries = [];
    setState(() {
      _showWaitTimes = false;
      _wtStopMarker = null;
      _mapPolylines.clear();
      _routeStopMarkers = {};
      _stopViewBusMarkers = {};
    });
    if (tappedIntoStop && _tappedStop?.StopNo != null) {
      _loadStopViewBusMarkers(_tappedStop!.StopNo!);
    }
  }

  Future<void> _rebuildWtBusMarkers() async {
    if (!mounted || !_showWaitTimes || _busIconImage == null) return;
    final static_ = GtfsStaticService();
    final allPositions = await GtfsRealtimeService().getVehiclePositions();
    if (!mounted || !_showWaitTimes) return;

    final routeNo = _wtRouteNo;
    final directionId = _wtDirectionId;
    final fresh = allPositions.where((v) {
      final routeId = v.routeId.isNotEmpty
          ? v.routeId
          : (static_.getTripInfo(v.tripId)?.routeId ?? '');
      if (removeZeroes(static_.getRouteShortName(routeId) ?? routeId) != routeNo) return false;
      final tripInfo = static_.getTripInfo(v.tripId);
      return tripInfo == null || tripInfo.directionId == directionId;
    }).toList();

    _wtBusEntries = fresh.map((v) {
      final routeId = v.routeId.isNotEmpty
          ? v.routeId
          : (static_.getTripInfo(v.tripId)?.routeId ?? '');
      return (v, removeZeroes(static_.getRouteShortName(routeId) ?? routeId));
    }).toList();

    if (_wtBusEntries.isEmpty) return;
    final image = _busIconImage!;
    final descriptors = await Future.wait(_wtBusEntries.map((e) =>
        MarkerHelper.createCustomMarkerBitmap(e.$2, 0, image,
            pixelRatio: _pixelRatio, ageLabel: _ageLabel(e.$1.lastSeen), isDark: darkModeOn)));
    if (!mounted || !_showWaitTimes) return;
    final markers = <Marker>{};
    for (int i = 0; i < _wtBusEntries.length; i++) {
      final v = _wtBusEntries[i].$1;
      markers.add(Marker(
        markerId: MarkerId('wt_bus_${v.vehicleId}_$i'),
        position: LatLng(v.latitude - 0.00005, v.longitude),
        icon: descriptors[i],
        onTap: () => _onBusMarkerTap(_wtRouteNo, v.tripId),
      ));
    }
    setState(() { _stopViewBusMarkers = markers; });
  }

  Future<void> _loadWaitTimesMapData(
      String routeNo, String rawPattern, String stopNo,
      {String? tripId}) async {
    setState(() {
      _mapPolylines.clear();
      _routeStopMarkers = {};
      _stopViewBusMarkers = {};
    });

    await GtfsStaticService().ensureLoaded();
    final static_ = GtfsStaticService();
    final color = static_.getRouteColor(routeNo, isDark: darkModeOn);

    // Resolve directionId: use the trip's own GTFS record when available,
    // otherwise fall back to inferring from the stop's street name.
    int directionId;
    if (tripId != null) {
      directionId = static_.getTripInfo(tripId)?.directionId ?? 0;
    } else {
      final stopCode = int.tryParse(stopNo);
      final refStop = stopCode != null ? static_.getStopByCode(stopCode) : null;
      final dir0 = GtfsUtil.directionFromStop(refStop?.OnStreet, 0);
      directionId = (dir0 == rawPattern) ? 0 : 1;
    }
    _wtDirectionId = directionId;

    // Use the specific trip's shape if available, otherwise fall back to direction
    if (tripId != null) {
      final shape = static_.getShapeForTrip(tripId);
      if (shape != null) addLines(routeNo, shape, 0, color);
    } else {
      final shapes = static_.getShapesForRouteAndDirection(routeNo, directionId);
      for (int i = 0; i < shapes.length; i++) {
        addLines(routeNo, shapes[i], i, color);
      }
    }

    final repTripId = tripId ?? static_.getRepresentativeTripId(routeNo, directionId: directionId);
    if (repTripId != null) {
      final stops = static_.getStopsForTrip(repTripId);
      final tripShape = static_.getShapeForTrip(repTripId);
      if (stops.isNotEmpty) {
        MarkerHelper.createDotMarker(size: 10, pixelRatio: _pixelRatio)
            .then((dotIcon) {
          final markers = <Marker>{};
          for (final stop in stops) {
            if (stop.Latitude == null || stop.Longitude == null) continue;
            final pos = tripShape != null
                ? _snapToPolyline(
                    LatLng(stop.Latitude!, stop.Longitude!), tripShape)
                : LatLng(stop.Latitude!, stop.Longitude!);
            markers.add(Marker(
              markerId: MarkerId('wt_routestop_${stop.StopNo}'),
              position: pos,
              icon: dotIcon,
              anchor: const Offset(0.5, 0.5),
            ));
          }
          if (mounted) setState(() { _routeStopMarkers = markers; });
        });
      }
    }

    final allPositions = await GtfsRealtimeService().getVehiclePositions();
    final matching = allPositions.where((v) {
      final routeId = v.routeId.isNotEmpty
          ? v.routeId
          : (static_.getTripInfo(v.tripId)?.routeId ?? '');
      if (removeZeroes(static_.getRouteShortName(routeId) ?? routeId) != routeNo) {
        return false;
      }
      final tripInfo = static_.getTripInfo(v.tripId);
      return tripInfo == null || tripInfo.directionId == directionId;
    }).toList();
    if (matching.isEmpty || !mounted) return;

    _busIconImage ??= await load('images/bus-icon-outline.png');

    _wtAgeTimer?.cancel();
    GtfsRealtimeService().invalidateCache();
    await _rebuildWtBusMarkers();
    _wtAgeTimer = Timer.periodic(const Duration(seconds: 1), (_) => _rebuildWtBusMarkers());
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

  Future<void> _showMarkerOverlay({
    required LatLng position,
    String? title,
    String? subtitle,
    DateTime? lastSeen,
  }) async {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    final coord = await mapController?.getScreenCoordinate(position);
    if (!mounted) return;
    setState(() {
      _overlayLatLng = position;
      _overlayCoord = coord;
      _overlayTitle = title;
      _overlaySubtitle = subtitle;
      _overlayBusLastSeen = lastSeen;
    });
    if (lastSeen != null) {
      _overlayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _dismissMarkerOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    setState(() {
      _overlayLatLng = null;
      _overlayCoord = null;
      _overlayTitle = null;
      _overlaySubtitle = null;
      _overlayBusLastSeen = null;
    });
  }

  void _repositionOverlay() {
    if (_overlayLatLng == null) return;
    mapController?.getScreenCoordinate(_overlayLatLng!).then((coord) {
      if (mounted) setState(() => _overlayCoord = coord);
    });
  }

  Widget _buildMarkerOverlay() {
    if (_overlayCoord == null) return const SizedBox.shrink();
    final bgColor = darkModeOn ? const Color.fromRGBO(50, 52, 58, 1) : Colors.white;
    final textColor = darkModeOn ? Colors.white : Colors.black87;
    final subColor = darkModeOn ? const Color.fromRGBO(142, 142, 147, 1) : Colors.grey.shade600;

    String? sub = _overlaySubtitle;
    if (_overlayBusLastSeen != null) {
      final secs = DateTime.now().difference(_overlayBusLastSeen!).inSeconds;
      sub = secs < 60 ? 'Last updated: ${secs}s' : 'Last updated: ${(secs / 60).floor()}m';
    }

    const arrowH = 6.0;
    const estWidth = 150.0;
    const estCardH = 46.0;

    return Positioned(
      left: _overlayCoord!.x.toDouble() - estWidth / 2,
      top: _overlayCoord!.y.toDouble() - estCardH - arrowH,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: estWidth),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_overlayTitle != null && _overlayTitle!.isNotEmpty)
                  Text(_overlayTitle!, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
                if (sub != null)
                  Text(sub, style: TextStyle(color: subColor, fontSize: 11)),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(12, arrowH),
            painter: _DownArrowPainter(bgColor),
          ),
        ],
      ),
    );
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
                    if (_showWaitTimes) return false;
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
                  .union(Set.from(selectedStop == null || _showWaitTimes ? [] : [selectedStop]))
                  .union(_routeStopMarkers)
                  .union(_stopViewBusMarkers)
                  .union(Set.from(_wtStopMarker == null ? [] : [_wtStopMarker])),
              onTap: (LatLng a) {
                _dismissMarkerOverlay();
                if (_showWaitTimes) {
                  _dismissWaitTimes();
                  return;
                }
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
              onCameraMove: (_) => _repositionOverlay(),
              onCameraIdle: () {
                if (!_mapReady) setState(() => _mapReady = true);
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
                    _showMarkerOverlay(
                      position: LatLng(_tappedStop!.Latitude ?? 0, _tappedStop!.Longitude ?? 0),
                      title: _tappedStop!.Name.toString(),
                      subtitle: _tappedStop!.StopNo.toString(),
                    );
                  }
                }
              },
            ),
            AnimatedOpacity(
              opacity: zoomBool && !_showWaitTimes ? 1.0 : 0.0,
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
            if (!_mapReady && darkModeOn)
              Positioned.fill(
                child: ColoredBox(color: colorFromHex('1b2336')),
              ),
            Visibility(
              visible: !showingSpecificBuses && !_showWaitTimes,
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
                        _saveTab();
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
              visible: !showingSpecificBuses && !_showWaitTimes,
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
                onTripTap: _openWaitTimes,
                onDotChanged: (routeIndex, dot) {
                  setState(() {
                    scrollSheetDotList[routeIndex] = dot;
                  });
                },
              ),
            ),
            Visibility(
              visible: !showingSpecificBuses && !_showWaitTimes,
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
            if (_showWaitTimes)
              WaitTimesSheet(
                key: _waitTimesKey,
                routeNo: _wtRouteNo,
                loading: _wtLoading,
                trips: _wtTrips,
                isDarkMode: darkModeOn,
                onDismiss: _clearWaitTimesState,
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
            _buildMarkerOverlay(),
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
        final double lat = latitude;
        final double lng = longitude;
        final String sName = stopName;
        final marker = Marker(
          markerId: MarkerId(stopNo),
          position: LatLng(lat, lng),
          icon: bitmapDescriptor,
          onTap: () {
            _showMarkerOverlay(
              position: LatLng(lat, lng),
              title: sName,
              subtitle: stopNo,
            );
          },
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

class _DownArrowPainter extends CustomPainter {
  final Color color;
  _DownArrowPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_DownArrowPainter old) => old.color != color;
}
