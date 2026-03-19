// Android build:
// flutter build apk --split-per-abi
// iOS build:
// flutter build ios --release

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transitapp/fetchers/BusAtSingleStopFetcher.dart';
import 'package:transitapp/fetchers/LocationFetcher.dart';
import 'package:transitapp/models/Bus.dart';
import 'package:transitapp/searchbar/searchBar.dart';
import 'package:transitapp/util/LifecycleEventHandler.dart';
import 'package:transitapp/util/MarkerHelper.dart';
import 'package:transitapp/util/SunsetHelper.dart';
import 'package:transitapp/util/TransitLiveTimer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:app_settings/app_settings.dart';

import 'WaitTimesPopup.dart';
import 'fetchers/BusAtStopFetcher.dart';
import 'fetchers/RouteMapCoordinateHelper.dart';
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

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<PolylineId, Polyline> _mapPolylines = {};
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
  var isSearching = false;
  var highlightedStopNo;
  var listOfStops = <Stop>[];
  var count = 0;
  var scrollsheetText = 'Searching For Buses...';
  var isLocationEnabled = true;
  var scrollSheetDotList = [];
  var tappedIntoStop = false;
  Position? userLocation;
  List<BothDirectionRouteWithTrips>? nextBusesCopy;
  List? scrollSheetDotListCopy;
  var shouldShowTranslinkOutage = false;

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
  final SearchBarController<Stop> searchBarController = SearchBarController();

  void vibrate() async {
    if (await Vibration.hasCustomVibrationsSupport()) {
      Vibration.vibrate(duration: 10);
    }
  }

  Future<Position> getLocation() async {
    if (userLocation != null) {
      return userLocation!;
    }
    return Geolocator.getCurrentPosition();
  }

  void showAquariumPopup() {
    final BuildContext? ctx = _scaffoldKey.currentContext;
    if (ctx == null) return;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: Image.asset('images/fishcopy.png'),
              ),
            ),
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.fromLTRB(10, 15, 5, 15),
              child: const Text(
                'Due to the COVID-19 Pandemic, the Vancouver Aquarium paused all public programming. '
                'During this time, essential donations would be put towards the critical care of over 70000 animals. '
                '100% of ad revenue from this app goes towards the Vancouver Aquarium',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.3,
                  fontWeight: FontWeight.w300,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
            ),
            Center(
              child: Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: getColorFromHex('256BD1'),
                      minimumSize: const Size(150, 55),
                    ),
                    child: const Text(
                      'Learn More',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.vanaqua.org/transformation'),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: getColorFromHex('256BD1'),
                      minimumSize: const Size(150, 55),
                    ),
                    child: const Text(
                      'Donate',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                    onPressed: () => launchUrl(
                      Uri.parse(
                          'https://www.vanaqua.org/support/ways-to-support'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void createAquariumMarker() async {
    final ui.Image image = await load('images/Aquarium Marker.png');
    final BitmapDescriptor imagea =
        await MarkerHelper.createCustomMarkerBitmapNoText(image, 150, 100);
    final Marker aquariumMarker = Marker(
      onTap: showAquariumPopup,
      markerId: const MarkerId('aquarium'),
      position: const LatLng(49.3002649, -123.1311801),
      icon: imagea,
    );
    _markers['aquarium'] = aquariumMarker;
  }

  void clearAndAddAquarium() {
    _markers.removeWhere((key, value) => key != 'aquarium');
  }

  void initWithLocation() {
    createAquariumMarker();
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

        if (isSelected[0] == false) {
          LocationFetcher().fetchAllBuses().then((value) {
            if (value.isEmpty) {
              setState(() {
                shouldShowTranslinkOutage = true;
              });
            }
          });
          updateNextBusesForAllNearbyStops();
        } else {
          updateBuses();
          updateNextBusesForAllNearbyStops();
        }
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
        const Duration(seconds: 1), (Timer t) => timerIfSelectedHelperShort());

    WidgetsBinding.instance.addObserver(LifecycleEventHandler(
      resumeCallBack: () async {
        if (hasLoaded) {
          timerIfSelectedHelper();
          timerIfSelectedHelperShort();
          timer = Timer.periodic(const Duration(seconds: 30),
              (Timer t) => timerIfSelectedHelper());
          timerShort = Timer.periodic(const Duration(seconds: 2),
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
        MarkerHelper.createCustomMarkerBitmap(bus.RouteNo ?? '', buses.indexOf(bus), image),
    ];

    final List<BitmapDescriptor> descriptors =
        await Future.wait(bitmapFutures);

    for (int i = 0; i < buses.length; i++) {
      final Bus bus = buses[i];
      final marker = Marker(
        onTap: () {
          setState(() {
            _mapPolylines.clear();
          });
          if (bus.RouteMap?.Href != null) {
            RouteMapCoordinateHelper()
                .getLatLng(bus.RouteMap!.Href!)
                .then((List<List<LatLng>> value) {
              int index = 0;
              for (final List<LatLng> list in value) {
                addLines(bus.RouteNo ?? '', list, index);
                index++;
              }
            });
          }
        },
        markerId: MarkerId(
            '${bus.VehicleNo}!${bus.RouteNo}!${bus.Pattern}'),
        position: LatLng(
            (bus.Latitude ?? 0) - 0.00005, bus.Longitude ?? 0),
        infoWindow: InfoWindow(
          title:
              '${patternHelper(bus.Pattern ?? '')} to ${bus.Destination ?? ''}',
        ),
        icon: descriptors[i],
      );
      l.add(marker);
    }
    return l;
  }

  void addLines(String routeNum, List<LatLng> listofLatLng, int index) {
    final PolylineId polylineId = PolylineId(index.toString());
    final Polyline polyline = Polyline(
      polylineId: polylineId,
      consumeTapEvents: true,
      color: Colors.teal,
      width: 5,
      points: listofLatLng,
    );
    setState(() {
      _mapPolylines[polylineId] = polyline;
    });
  }

  Future<List<Stop>> search(String searchText) async {
    setState(() {
      isSearching = true;
    });
    final List<Stop> toRet = [];
    for (final Stop s in listOfStops) {
      if ((s.Name?.toLowerCase().contains(searchText.toLowerCase()) ?? false) ||
          s.StopNo.toString().contains(searchText)) {
        final Stop newStop = Stop()
          ..StopNo = s.StopNo
          ..Name = s.Name
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
          highlightedStopNo == stop.StopNo ? 110 : 75,
          highlightedStopNo == stop.StopNo ? 110 : 75,
        ),
    ];

    final List<BitmapDescriptor> descriptors =
        await Future.wait(bitmapFutures);

    for (int i = 0; i < stops.length; i++) {
      final Stop stop = stops[i];
      final marker = Marker(
        onTap: () {
          setState(() {
            if (!tappedIntoStop) {
              nextBusesCopy =
                  List<BothDirectionRouteWithTrips>.from(nextBuses);
              scrollSheetDotListCopy =
                  List<dynamic>.from(scrollSheetDotList);
            }
            tappedIntoStop = true;
            count = 2;
            BusAtSingleStopFetcher()
                .busAtSingleStopFetcher(stop, stop.StopNo.toString())
                .then((List<BothDirectionRouteWithTrips> value) {
              renderListOfNextBuses(value);
            });
          });
        },
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

  void updateNextBusesForAllNearbyStops() async {
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

    final List<Stop> stops = listOfStops;
    final List<BothDirectionRouteWithTrips> buses =
        await BusAtStopFetcher().busFetcher(
      stops,
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
    setState(() {
      isLoading = true;
    });
    final List<Bus> buses = await LocationFetcher().fetchAllBuses();
    final List<Marker> list = await getBusList(buses);
    setState(() {
      isLoading = false;
      clearAndAddAquarium();
      for (final Marker m in list) {
        _markers[m.markerId.toString()] = m;
      }
    });
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

  void updateStops(String latitude, String longitude) async {
    final List<Stop> stops =
        await StopFetcher().stopFetcher(latitude, longitude);
    final List<Marker> list = await getStopList(stops);
    setState(() {
      clearAndAddAquarium();
      for (final Marker m in list) {
        _markers[m.markerId.toString()] = m;
      }
    });
  }

  void updateStopsForMap(double latitude1, double latitude2,
      double longitude1, double longitude2) async {
    clearAndAddAquarium();
    final List<Stop> validStops = [
      for (final Stop s in listOfStops)
        if ((s.Latitude ?? 0) < latitude1 &&
            (s.Latitude ?? 0) > latitude2 &&
            (s.Longitude ?? 0) < longitude1 &&
            (s.Longitude ?? 0) > longitude2)
          s,
    ];
    final List<Marker> list = await getStopList(validStops);
    setState(() {
      clearAndAddAquarium();
      for (final Marker m in list) {
        _markers[m.markerId.toString()] = m;
      }
    });
  }

  String patternHelper(String s) {
    if (s.startsWith('E')) return 'EASTBOUND';
    if (s.startsWith('N')) return 'NORTHBOUND';
    if (s.startsWith('W')) return 'WESTBOUND';
    if (s.startsWith('S')) return 'SOUTHBOUND';
    if (s.toLowerCase() == 'outbound') return 'OUTBOUND';
    if (s.toLowerCase() == 'inbound') return 'INBOUND';
    return s.toUpperCase();
  }

  String removeZeroes(String s) {
    while (s.isNotEmpty && s.substring(0, 1) == '0') {
      s = s.substring(1);
    }
    return s;
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
        );
      },
      fullscreenDialog: true,
    ));
  }

  void _currentLocation() {
    if (mapController == null || userLocation == null) return;
    try {
      setState(() {
        isLocationEnabled = true;
        isLocationOnMapEnabled = true;
      });
      hasAnimated = true;
      mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          bearing: 0,
          target: LatLng(userLocation!.latitude, userLocation!.longitude),
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
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          key: _scaffoldKey,
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
                  .union(Set.from(
                      selectedStop == null ? [] : [selectedStop])),
              onTap: (LatLng a) {
                tappedIntoStop = false;
                searchBarController.clear();
                setState(() {
                  if (nextBusesCopy != null &&
                      scrollSheetDotListCopy != null) {
                    nextBuses = nextBusesCopy!;
                    scrollSheetDotList = scrollSheetDotListCopy!;
                  }
                  _mapPolylines.clear();
                });
              },
              onCameraIdle: () {
                count--;
                if (count <= 0) {
                  tappedIntoStop = false;
                  highlightedStopNo = null;
                  setState(() {
                    if (nextBusesCopy != null &&
                        scrollSheetDotListCopy != null) {
                      nextBuses = nextBusesCopy!;
                      scrollSheetDotList = scrollSheetDotListCopy!;
                    }
                  });
                  if (isSelected[0] == false) {
                    showZoomInIfNeeded();
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
                top: 105,
                right: 7,
                left: 7,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: getColorFromHex('cfd1d4'),
                      borderRadius:
                          BorderRadius.all(Radius.circular(20)),
                    ),
                    child: ToggleButtons(
                      fillColor: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      children: const <Widget>[
                        Icon(Icons.directions_bus),
                        Icon(Icons.pin_drop),
                      ],
                      onPressed: (int index) {
                        vibrate();
                        if (nextBusesCopy != null &&
                            scrollSheetDotListCopy != null) {
                          nextBuses = nextBusesCopy!;
                          scrollSheetDotList = scrollSheetDotListCopy!;
                        }
                        if (index == 0) {
                          updateBuses();
                          setState(() {
                            zoomBool = false;
                          });
                        } else {
                          _mapPolylines.clear();
                          showZoomInIfNeeded();
                          getLocationAndUpdateStops();
                        }
                        setState(() {
                          for (int buttonIndex = 0;
                              buttonIndex < isSelected.length;
                              buttonIndex++) {
                            isSelected[buttonIndex] =
                                buttonIndex == index;
                          }
                        });
                      },
                      isSelected: isSelected,
                    ),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: !showingSpecificBuses,
              child: Positioned(
                top: 162,
                right: 7,
                left: 7,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: SizedBox(
                    height: 50,
                    width: 50,
                    child: FittedBox(
                      child: FloatingActionButton(
                        heroTag: 'subway',
                        onPressed: _currentLocation,
                        backgroundColor:
                            const Color.fromRGBO(255, 255, 255, 1),
                        child: const Icon(
                          Icons.my_location,
                          size: 24,
                          color: Color.fromRGBO(0, 0, 0, 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 105,
              left: 10,
              child: Align(
                alignment: Alignment.bottomRight,
                child: SizedBox(
                  height: 50,
                  width: 50,
                  child: FittedBox(
                    child: FloatingActionButton(
                      heroTag: 'vanaqua',
                      onPressed: showAquariumPopup,
                      backgroundColor:
                          const Color.fromRGBO(255, 255, 255, 1),
                      child: IconButton(
                        icon: Image.asset('images/Aquarium Marker.png'),
                        onPressed: showAquariumPopup,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: !showingSpecificBuses,
              child: DraggableScrollableSheet(
                initialChildSize: 0.4,
                minChildSize: 0.2,
                maxChildSize: 0.8,
                builder:
                    (BuildContext context, myscrollController) {
                  return Container(
                    color: Colors.deepOrangeAccent.withAlpha(0),
                    child: Stack(children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(
                            0.0, 27.0, 0.0, 0.0),
                        color: darkModeOn
                            ? getColorFromHex('1b2336')
                                .withAlpha(252)
                            : Colors.white.withAlpha(252),
                        child: Stack(children: [
                          AnimatedOpacity(
                            opacity:
                                nextBuses.isNotEmpty ? 1.0 : 0.0,
                            duration:
                                const Duration(milliseconds: 2),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  0, 15, 0, 0),
                              controller: myscrollController,
                              itemCount: nextBuses.length,
                              itemBuilder:
                                  (BuildContext context, int index) {
                                return ListTile(
                                  key: Key(nextBuses[index]
                                      .RouteNo
                                      .toString()),
                                  title: Column(children: [
                                    CarouselSlider(
                                      options: CarouselOptions(
                                        onPageChanged:
                                            (carouselIndex,
                                                reason) {
                                          setState(() {
                                            scrollSheetDotList[
                                                    index] =
                                                carouselIndex;
                                          });
                                        },
                                        height: 64.0,
                                        viewportFraction: 1.0,
                                      ),
                                      items: nextBuses[index]
                                          .Trips
                                          .map((trip) {
                                        return Builder(
                                          builder:
                                              (BuildContext context) {
                                            return InkWell(
                                              onTap: () {
                                                openWaitTimesPopup(
                                                  nextBuses[index]
                                                      .RouteNo,
                                                  trip.Pattern ?? '',
                                                  trip.StopNo ?? '',
                                                );
                                              },
                                              child: Column(
                                                children: <Widget>[
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: <
                                                        Widget>[
                                                      Container(
                                                        width: 70,
                                                        margin: const EdgeInsets
                                                            .only(
                                                            right: 0,
                                                            left: 0),
                                                        child: Text(
                                                          removeZeroes(
                                                              nextBuses[
                                                                      index]
                                                                  .RouteNo),
                                                          textAlign:
                                                              TextAlign
                                                                  .center,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: removeZeroes(nextBuses[index].RouteNo).length < 3
                                                                ? 50
                                                                : 35,
                                                            height: 1.0,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            color: darkModeOn
                                                                ? Colors
                                                                    .white70
                                                                : getColorFromHex(
                                                                    '#10295D'),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: <
                                                              Widget>[
                                                            Container(
                                                              margin: const EdgeInsets
                                                                  .only(
                                                                  left:
                                                                      15),
                                                              child:
                                                                  Text(
                                                                nextBuses[index]
                                                                        .Trips[scrollSheetDotList[index]]
                                                                        .Destination ??
                                                                    '',
                                                                textAlign:
                                                                    TextAlign
                                                                        .left,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  fontSize:
                                                                      18,
                                                                  fontWeight:
                                                                      FontWeight.w700,
                                                                  height:
                                                                      1.0,
                                                                  color: darkModeOn
                                                                      ? Colors.white70
                                                                      : getColorFromHex('#024D7E'),
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              margin: const EdgeInsets
                                                                  .only(
                                                                  left:
                                                                      15),
                                                              child:
                                                                  Text(
                                                                '${patternHelper(nextBuses[index].Trips[scrollSheetDotList[index]].Pattern ?? '')} at \n${nextBuses[index].Trips[scrollSheetDotList[index]].nextStop ?? ''}',
                                                                textAlign:
                                                                    TextAlign
                                                                        .left,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        15,
                                                                    height:
                                                                        1.0,
                                                                    fontWeight:
                                                                        FontWeight.w400,
                                                                    color: getColorFromHex('1bab65')),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 83,
                                                        child: Text(
                                                          '${nextBuses[index].Trips[scrollSheetDotList[index]].ExpectedCountdown ?? 0} min',
                                                          textAlign:
                                                              TextAlign
                                                                  .center,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: (nextBuses[index].Trips[scrollSheetDotList[index]].ExpectedCountdown?.toString().length ?? 1) < 3
                                                                ? 24
                                                                : 20,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            height:
                                                                1.0,
                                                            color: darkModeOn
                                                                ? Colors
                                                                    .white70
                                                                : getColorFromHex(
                                                                    '#10295D'),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: nextBuses[index]
                                          .Trips
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        return Container(
                                          width: 6.0,
                                          height: 5.0,
                                          margin: const EdgeInsets
                                              .symmetric(
                                              vertical: 2.0,
                                              horizontal: 2.0),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: scrollSheetDotList[
                                                        index] ==
                                                    entry.key
                                                ? (darkModeOn
                                                    ? const Color
                                                        .fromRGBO(
                                                        255,
                                                        255,
                                                        255,
                                                        0.3)
                                                    : const Color
                                                        .fromRGBO(0,
                                                        0, 0, 0.3))
                                                : (darkModeOn
                                                    ? const Color
                                                        .fromRGBO(
                                                        255,
                                                        255,
                                                        255,
                                                        0.15)
                                                    : const Color
                                                        .fromRGBO(0,
                                                        0, 0, 0.15)),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    Divider(
                                      color: Theme.of(context)
                                          .primaryColor,
                                    ),
                                  ]),
                                );
                              },
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                AnimatedOpacity(
                                  opacity: nextBuses.isEmpty
                                      ? 1.0
                                      : 0.0,
                                  duration: const Duration(
                                      milliseconds: 20),
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight:
                                              FontWeight.w500,
                                          fontStyle:
                                              FontStyle.normal,
                                          fontSize: 19,
                                        ),
                                        text: scrollsheetText,
                                      ),
                                    ),
                                  ),
                                ),
                                Visibility(
                                  visible: !isLocationEnabled,
                                  child: Flexible(
                                    child: Container(
                                      padding:
                                          const EdgeInsets.fromLTRB(
                                              35, 10, 30, 0),
                                      child: RichText(
                                        text: TextSpan(
                                          recognizer:
                                              TapGestureRecognizer()
                                                ..onTap = () {
                                                  AppSettings
                                                      .openAppSettings(
                                                          type: AppSettingsType
                                                              .location);
                                                },
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight:
                                                FontWeight.w300,
                                            fontStyle:
                                                FontStyle.normal,
                                            fontSize: 16,
                                          ),
                                          text: !tappedIntoStop
                                              ? 'Please allow Transit to access your location to improve your experience'
                                              : '',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                      Positioned(
                        right: 70.0,
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: FittedBox(
                            child: FloatingActionButton(
                              heroTag: 'pizzahut',
                              onPressed: () {
                                if (!tappedIntoStop) {
                                  updateNextBusesForAllNearbyStops();
                                }
                                if (isSelected[0] == true) {
                                  updateBuses();
                                }
                              },
                              backgroundColor: Colors.grey,
                              child: const Icon(
                                Icons.refresh,
                                size: 50,
                                color:
                                    Color.fromRGBO(255, 255, 255, 0.9),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0.0,
                        child: TransitLiveTimer(
                            isLoading, timeDifference),
                      ),
                    ]),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              left: 0,
              child: AnimatedOpacity(
                opacity: isSearching ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Visibility(
                  visible: isSearching,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: !showingSpecificBuses,
              child: TransitSearchBar<Stop>(
                searchBarController: searchBarController,
                minimumChars: 1,
                hintText: 'Search for stops',
                textStyle: const TextStyle(fontSize: 18),
                shrinkWrap: true,
                placeHolder: const SizedBox.shrink(),
                contentPadding: EdgeInsets.zero,
                searchBarPadding:
                    const EdgeInsets.fromLTRB(10, 20, 10, 0),
                searchBarStyle: SearchBarStyle(
                  searchBarHeight: 52,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                  borderRadius: BorderRadius.circular(20),
                ),
                onSearch: search,
                onCancelled: () {
                  highlightedStopNo = null;
                  FocusScope.of(context).requestFocus(FocusNode());
                  setState(() {
                    isSearching = false;
                  });
                },
                onError: (error) {
                  return const Text('no error');
                },
                emptyWidget: Align(
                  alignment: Alignment.center,
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: Colors.black87,
                        fontStyle: FontStyle.normal,
                        fontSize: 18,
                      ),
                      text: 'No Stops Found',
                    ),
                  ),
                ),
                onItemFound: (Stop post, int index) {
                  return ListTile(
                    title: Text(post.StopNo.toString()),
                    subtitle: Text(post.Name ?? ''),
                    onTap: () {
                      setState(() {
                        if (!tappedIntoStop) {
                          nextBusesCopy =
                              List<BothDirectionRouteWithTrips>.from(
                                  nextBuses);
                          scrollSheetDotListCopy =
                              List<dynamic>.from(scrollSheetDotList);
                        }
                        tappedIntoStop = true;
                        isSelected = [false, true];
                        BusAtSingleStopFetcher()
                            .busAtSingleStopFetcher(
                                post, post.StopNo.toString())
                            .then((List<BothDirectionRouteWithTrips>
                                value) {
                          renderListOfNextBuses(value);
                        });
                      });
                      searchBarController.clear();
                      final CameraPosition kLake = CameraPosition(
                          target: LatLng(
                              post.Latitude ?? 0, post.Longitude ?? 0),
                          zoom: 18);
                      highlightedStopNo = post.StopNo;
                      count = 2;
                      updateStops(
                          (post.Latitude ?? 0).toString(),
                          (post.Longitude ?? 0).toString());
                      mapController?.animateCamera(
                          CameraUpdate.newCameraPosition(kLake));
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
                            const Color.fromRGBO(255, 255, 255, 0.25),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          size: 25,
                          color: Color.fromRGBO(255, 255, 255, 0.85),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: shouldShowTranslinkOutage && isSelected[0],
              child: Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.center,
                  child: Card(
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 10),
                        const ListTile(
                          title:
                              Text('Bus Locations Temporarily Unavailable'),
                          subtitle: Text(
                              'Due to the ongoing Translink IT outage, only next stop times are available.'),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            TextButton(
                              child: const Text('Learn More'),
                              onPressed: () {
                                launchUrl(Uri.parse(
                                  'https://www.translink.ca/news/2020/december/statement%20from%20translink%20ceo%20kevin%20desmond',
                                ));
                              },
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              child: const Text('Dismiss'),
                              onPressed: () {
                                setState(() {
                                  shouldShowTranslinkOutage = false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );

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
          clearAndAddAquarium();
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
      MarkerHelper.createCustomMarkerBitmapNoText(image, 75, 75)
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

///
/// Given a HEX color string, return a Color object
///
Color getColorFromHex(String hexColor) {
  final String h = hexColor.toUpperCase().replaceAll('#', '');
  return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
}
