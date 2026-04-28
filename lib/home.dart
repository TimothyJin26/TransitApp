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
          highlightedStopNo == stop.StopNo ? 60 : 38,
          highlightedStopNo == stop.StopNo ? 60 : 38,
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
                  List<int>.from(scrollSheetDotList);
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
    setState(() {
      isLoading = true;
    });
    final List<Bus> buses = await LocationFetcher().fetchAllBuses();
    final List<Marker> list = await getBusList(buses);
    setState(() {
      isLoading = false;
      _markers.clear();
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
      _markers.clear();
      for (final Marker m in list) {
        _markers[m.markerId.toString()] = m;
      }
    });
  }

  void updateStopsForMap(double latitude1, double latitude2,
      double longitude1, double longitude2) async {
    _markers.clear();
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
      _markers.clear();
      for (final Marker m in list) {
        _markers[m.markerId.toString()] = m;
      }
    });
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
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: darkModeOn ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          key: _scaffoldKey,
          resizeToAvoidBottomInset: false,
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
                _searchBarController.clear();
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
                top: 116,
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
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
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
                              List<int>.from(scrollSheetDotList);
                        }
                        tappedIntoStop = true;
                        _tappedStop = post;
                        isSelected = [false, true];
                        BusAtSingleStopFetcher()
                            .busAtSingleStopFetcher(
                                post, post.StopNo.toString())
                            .then((List<BothDirectionRouteWithTrips>
                                value) {
                          renderListOfNextBuses(value);
                        });
                      });
                      _searchBarController.clear();
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
      MarkerHelper.createCustomMarkerBitmapNoText(image, 56, 56)
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


