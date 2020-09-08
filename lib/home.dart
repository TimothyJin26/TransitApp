//flutter build apk --split-per-abi

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:ads/ads.dart';
import 'package:app_settings/app_settings.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_beautiful_popup/main.dart';
import 'dart:ui' as ui;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/services.dart' show PlatformException, rootBundle;
import 'package:firebase_admob/firebase_admob.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transitapp/fetchers/BusAtSingleStopFetcher.dart';
import 'package:transitapp/models/Bus.dart';
import 'package:transitapp/fetchers/LocationFetcher.dart';

//import 'package:location/location.dart';
import 'package:transitapp/popuptemplates/MyTemplate.dart';
import 'package:transitapp/searchbar/searchBar.dart';
import 'package:transitapp/util/LifecycleEventHandler.dart';
import 'package:transitapp/util/MarkerHelper.dart';
import 'package:vibration/vibration.dart';

import 'Util.dart';
import 'fetchers/BusAtStopFetcher.dart';
import 'fetchers/NextBusesForRouteAtStop.dart';
import 'fetchers/RouteMapCoordinateHelper.dart';
import 'fetchers/StopFetcher.dart';
import 'models/BothDirectionRouteWithTrips.dart';
import 'models/Stop.dart';
import 'models/Trip.dart';

///
/// Main stateful widget
///
class TransitApp extends StatefulWidget {
  @override
  _TransitAppState createState() => _TransitAppState();
}

///
/// Contains the state of the home screen
/// The widget is rendered based on the state defined here
///
class _TransitAppState extends State<TransitApp> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<PolylineId, Polyline> _mapPolylines = {};
  Timer timer;
  Timer timerShort;
  List<bool> isSelected = [true, false];
  List<BothDirectionRouteWithTrips> nextBuses = [];
  var timeNow = new DateTime.now();
  var timeDifference = new Duration();
  var timeLastUpdated = DateTime.now();
  var timeLastUpdatedForInit = null;
  var isLoading = true;
  var zoomBool = false;
  var isSearching = false;
  var highlightedStopNo;
  var listOfStops = List<Stop>();
  var count = 0;
  var scrollsheetText = "Searching For Buses...";
  var isLocationEnabled = true;
  var scrollSheetDotList = [];
  var tappedIntoStop = false;
  Position userLocation = null;
  List<BothDirectionRouteWithTrips> nextBusesCopy = null;
  List scrollSheetDotListCopy = null;

  var selectedRouteNo;
  var selectedPattern;
  var selectedStop;

  Ads appAds;

  final String appId = Platform.isAndroid
      ? 'ca-app-pub-6078575452513504~1720853236'
      : 'ca-app-pub-6078575452513504~1720853236';

  final String bannerUnitId = Platform.isAndroid
      //test
//      ? 'ca-app-pub-3940256099942544/6300978111'
      //real
      ? 'ca-app-pub-6078575452513504/9492188580'
      //ios
      : 'ca-app-pub-6078575452513504/5469183098';

  StreamSubscription<ConnectivityResult> subscription;
  StreamSubscription<Position> positionStream;

  bool hasAnimated = false;

  // Markers of buses to display on the home screen (vehicle ID to marker)
  Map<String, Marker> _markers = {};
  bool showingSpecificBuses = false;

  bool hasLoaded = false;

  void vibrate() async {
    if (await Vibration.hasCustomVibrationsSupport()) {
      Vibration.vibrate(duration: 10);
    }
  }

  Future<Position> getLocation() async {
    if (userLocation != null) {
      print("USER LOCATION IS NOT NULL");
      return userLocation;
    } else {
      print("GETTING CURRENT LOCATION...");
      return getCurrentPosition(
//        locationPermissionLevel: GeolocationPermission.locationWhenInUse,
          );
    }
  }

  void initWithLocation() {
    if (timeLastUpdatedForInit == null ||
        new DateTime.now().difference(timeLastUpdatedForInit).inSeconds > 5) {
      timeLastUpdatedForInit = DateTime.now();
      print("Started initWithLocation");
//      Location location = new Location();
//      LocationData locationData;
//      location.getLocation().then((value) {
      getLocation().then((locationData) {
        userLocation = locationData;
        if (!hasAnimated) {
          _currentLocation();
        }
        print("Found initWithLocation success");
        setState(() {
          isLocationEnabled = true;
        });
        print('Found location: ' +
            locationData.latitude.toString() +
            ', ' +
            locationData.longitude.toString());

        // TODO: Update the markers on a regular basis
        //isSelected[0] == false
        if (isSelected[0] == false) {
          print("Starting by updating stops");
          //updateStops renders stops
          updateStops(locationData.latitude.toString(),
              locationData.longitude.toString());
        } else {
          print("Starting by updating buses");
          updateBuses();

          // render the next buses on scrollsheet
          updateNextBusesForAllNearbyStops();
        }
        hasLoaded = true;
      }).catchError((onError) {
        hasLoaded = true;
        print("Found initWithLocation error");
        print(onError.toString());
        setState(() {
          isLocationEnabled = false;
          scrollsheetText = "Location Services Disabled";
        });
      });
    } else {
      print("Updated too frequently");
    }
  }

  @override
  void initState() {
    super.initState();

    try {
      positionStream = getPositionStream().listen((Position position) {
        userLocation = position;
      });
    } catch (e) {
      // Permission Denied
    }

    appAds = Ads(
      appId,
      bannerUnitId: bannerUnitId,
      size: AdSize.banner,
      testing: false,
    );

    appAds.showBannerAd();

    //Location stuff moved from onMapCreated

//   catch (e) {
//      // User did not grant location permissions
//      if (e.code != 'PERMISSION_DENIED') {
//        throw e;
//      }
//    }

    //Previous stuff
    listOfStops.clear();
    rootBundle.loadString('assets/stops.txt').then((stopList) {
      List<String> lines = stopList.split('\n');
      var header = lines[0].split(',');
      int StopNoCol = header.indexOf("stop_code");
      int NameCol = header.indexOf("stop_name");
      int LongCol = header.indexOf("stop_lon");
      int LatCol = header.indexOf("stop_lat");
      lines.removeAt(0);
      for (String l in lines) {
        Stop s = new Stop();
        List<String> paste = l.split(',');
        try {
          s.StopNo = (int.parse(paste[StopNoCol]));
        } catch (e) {
          continue;
        }
        s.Name = paste[NameCol];
        s.Longitude = double.parse(paste[LongCol]);
        if (paste[NameCol].contains('@')) {
          s.OnStreet = paste[NameCol].split('@')[0];
          s.AtStreet = paste[NameCol].split('@')[1];
        } else {
          s.OnStreet = paste[NameCol];
          s.AtStreet = "";
        }

        s.Latitude = double.parse(paste[LatCol]);
        listOfStops.add(s);
      }
    });

    // Updates the bus locations every 30 seconds
    timer = Timer.periodic(
        Duration(seconds: 30), (Timer t) => timerIfSelectedHelper());

    // Updates the countdown clock every 2 seconds
    timerShort = Timer.periodic(
        Duration(seconds: 2), (Timer t) => timerIfSelectedHelperShort());

    // TODO: Go to https://stackoverflow.com/questions/49869873/flutter-update-widgets-on-resume
    //       Copy the LifecycleEventHandler class (including imports)
    //       Add code to cancel
    WidgetsBinding.instance.addObserver(LifecycleEventHandler(
        resumeCallBack: () async => setState(() {
              if (hasLoaded) {
                print(
                    "TIMER RECREATED TIMER RECREATED TIMER RECREATED TIMER RECREATED TIMER RECREATED ");
                timerIfSelectedHelper();
                timerIfSelectedHelperShort();
                timer = Timer.periodic(Duration(seconds: 30),
                    (Timer t) => timerIfSelectedHelper());

                // Updates the countdown clock every 2 seconds
                timerShort = Timer.periodic(Duration(seconds: 2),
                    (Timer t) => timerIfSelectedHelperShort());

                subscription?.resume();
                positionStream?.resume();

                initWithLocation();
              }
            }),
        suspendingCallBack: () async => setState(() {
              if (hasLoaded) {
                print(
                    "TIMER CANCELED TIMER CANCELED TIMER CANCELED TIMER CANCELED TIMER CANCELED TIMER CANCELED ");
                timer?.cancel();
                timerShort?.cancel();
                subscription?.pause();
                positionStream?.pause();
              }
            })));

    Connectivity().checkConnectivity().then((connectivityResult) {
      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          scrollsheetText = "No Internet Connection";
        });

        // Listen for connectivity changes, in case user gets internet later
        subscription = Connectivity()
            .onConnectivityChanged
            .listen((ConnectivityResult result) {
          if (result != ConnectivityResult.none) {
            print("Connectivity changed - found connection");
            initWithLocation();
          } else {
            scrollsheetText = "No Internet Connection";
          }
        });
      } else {
        print("Connectivity available - found connection");
        initWithLocation();
      }
      // I am connected to a wifi network.
    });
  }

  void timerIfSelectedHelperShort() {
    timeNow = DateTime.now();
    setState(() {
      timeDifference = timeNow.difference(timeLastUpdated);
    });
    if (isSelected[0] == true) {
//      setState(() {
//        for (String key in _markers.keys) {
//          final marker = Marker(
//              onTap: _markers[key].onTap,
//              markerId: _markers[key].markerId,
//              position: LatLng(_markers[key].position.latitude + 0.0001,
//                  _markers[key].position.longitude + 0.1),
//              infoWindow: _markers[key].infoWindow,
//              icon: _markers[key].icon);
//          _markers[key] = marker;
//          //The Great Migration
//        }
//      });
    }
  }

  void timerIfSelectedHelper() {
    if (!tappedIntoStop) {
      updateNextBusesForAllNearbyStops();
    }
    timeLastUpdated = DateTime.now();
    if (isSelected[0] == true) {
      updateBuses();
      print("140");
    }
  }

  void dispose() {
    subscription?.cancel();
    positionStream?.cancel();
    timer?.cancel();
    timerShort?.cancel();
    super.dispose();
  }

// Color of the marker
  final String colorOfMarker = "blue";

  ///
  /// Get a list of bus markers that can be used to plot on the map
  ///

  Future<List<Marker>> getBusList(List<Bus> buses) async {
    List<Marker> l = new List();
    List<Future<BitmapDescriptor>> bitmapFutures = new List();

    // Add image
    // TODO: Change icon depending on bus direction
    ui.Image image = await load('images/bus-icon-outline.png');

    for (var i = 0; i < buses.length; i++) {
      Bus bus = buses[i];
      bitmapFutures
          .add(MarkerHelper.createCustomMarkerBitmap(bus.RouteNo, i, image));
//      print("Added bus with route " + bus.RouteNo.toString());
    }

    List<BitmapDescriptor> futures = await Future.wait(bitmapFutures);
    for (var i = 0; i < buses.length; i++) {
      Bus bus = buses[i];
//      print("Parsing bus with route " + bus.RouteNo.toString());
      BitmapDescriptor bitmapDescriptor = futures[i];
      // TODO: Customize marker
      // https://stackoverflow.com/questions/54041830/how-to-add-extra-into-text-into-flutter-google-map-custom-marker

      final marker = Marker(
          //Bus Marker
          onTap: () {
//            mapController.showMarkerInfoWindow(MarkerId(bus.VehicleNo));
            setState(() {
              _mapPolylines.clear();
            });
            RouteMapCoordinateHelper r = new RouteMapCoordinateHelper();
            Future<List<List<LatLng>>> route = r.getLatLng(bus.RouteMap.Href);

            route.then((List<List<LatLng>> value) {
              int index = 0;
              for (List<LatLng> list in value) {
                addLines(bus.RouteNo, list, index);
                index++;
              }
            });
          },
          markerId:
              MarkerId(bus.VehicleNo + "!" + bus.RouteNo + "!" + bus.Pattern),
          position: LatLng(bus.Latitude - 0.00005, bus.Longitude),
          infoWindow: InfoWindow(
            title: patternHelper(bus.Pattern) + " to " + bus.Destination,
          ),
          icon: bitmapDescriptor);
      l.add(marker);
    }
    return l;
  }

  void addLines(String routeNum, List<LatLng> listofLatLng, int index) {
    final String polylineIdVal = index.toString();
    final PolylineId polylineId = PolylineId(polylineIdVal);

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

  ///MightyFamine
  void updateScrollableStopListOnTap() {}

  ///FantasticFamine
  Future<List<Stop>> search(String search) async {
    int counter = 0;
    setState(() {
      isSearching = true;
    });
    List<Stop> toRet = new List<Stop>();
    for (Stop s in listOfStops) {
      if (s.Name.toLowerCase().contains(search.toLowerCase()) ||
          s.StopNo.toString().contains(search)) {
        counter++;
        Stop newStop = new Stop();
        newStop.StopNo = s.StopNo;
        newStop.Name = s.Name;
        newStop.Longitude = s.Longitude;
        newStop.Latitude = s.Latitude;

        toRet.add(newStop);

        if (counter > 20) {
          break;
        }
      }
    }
    return toRet;
  }

  ///
  /// Get a list of stop markers that can be used to plot on the map
  ///
  Future<List<Marker>> getStopList(List<Stop> stops) async {
    List<Marker> l = new List();
    List<Future<BitmapDescriptor>> bitmapFutures = new List();
    // Add image
    // TODO: Change icon depending on bus direction
    ui.Image image = await load('images/StopIcon.png');

    for (var i = 0; i < stops.length; i++) {
      Stop stop = stops[i];
      if (highlightedStopNo == stops[i].StopNo) {
        bitmapFutures
            .add(MarkerHelper.createCustomMarkerBitmapNoText(image, 110, 110));
      } else {
        bitmapFutures
            .add(MarkerHelper.createCustomMarkerBitmapNoText(image, 75, 75));
//      print("Added bus with route " + bus.RouteNo.toString());
      }
    }

    List<BitmapDescriptor> futures = await Future.wait(bitmapFutures);
    for (var i = 0; i < stops.length; i++) {
      Stop stop = stops[i];
//      print("Parsing bus with route " + bus.RouteNo.toString());
      BitmapDescriptor bitmapDescriptor = futures[i];
      // TODO: Customize marker
      // https://stackoverflow.com/questions/54041830/how-to-add-extra-into-text-into-flutter-google-map-custom-marker
      final marker = Marker(
          //Stop Marker
          onTap: () {
            // On Tap stop marker, update the next buses
            setState(() {
              if (!tappedIntoStop) {
                nextBusesCopy =
                    List<BothDirectionRouteWithTrips>.from(nextBuses);
                scrollSheetDotListCopy = List<dynamic>.from(scrollSheetDotList);
              }
              tappedIntoStop = true;
              count = 2;
              BusAtSingleStopFetcher busFetcher = new BusAtSingleStopFetcher();
              Future<List<BothDirectionRouteWithTrips>> futureBuses = busFetcher
                  .busAtSingleStopFetcher(stop, stop.StopNo.toString());
              futureBuses.then((List<BothDirectionRouteWithTrips> value) {
                List<BothDirectionRouteWithTrips> buses = value;
                renderListOfNextBuses(buses);
              });
            });
          },
          markerId: MarkerId(stop.StopNo.toString()),
          position: LatLng(stop.Latitude, stop.Longitude),
          infoWindow: InfoWindow(
            title: stop.Name.toString(),
            snippet: stop.StopNo.toString(),
          ),
          icon: bitmapDescriptor);
      l.add(marker);
    }
    return l;
  }

  /// Renders scrollable scrollsheet
  void updateNextBusesForAllNearbyStops() async {
    print("somewhere at the start");
    Position locationData;
    try {
      locationData = await getLocation();
      setState(() {
        isLocationEnabled = true;
        scrollsheetText = "Searching For Buses...";
      });
    } catch (e) {
      print("User did not grant location permissions");
      setState(() {
        isLocationEnabled = false;
        scrollsheetText = "Location Services Disabled";
      });
      return;
      // User did not grant location permissions
    }
    print("somewhere slightly lower");
    // fetches stops based on location
    StopFetcher stopFetcher = new StopFetcher();

//    Future<List<Stop>> future = stopFetcher.stopFetcher(
//        locationData.latitude.toString(), locationData.longitude.toString());
//    print("somewhere in the middle");
    // gets next buses from each stop
    List<Stop> stops = listOfStops;
    BusAtStopFetcher busFetcher = new BusAtStopFetcher();
    Future<List<BothDirectionRouteWithTrips>> futureBuses = busFetcher
        .busFetcher(stops, locationData.latitude, locationData.longitude);
    List<BothDirectionRouteWithTrips> buses = await futureBuses;
    print(
        "OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO");
    renderListOfNextBuses(buses);
    setState(() {
      isLocationEnabled = true;
    });
    print("somewhere at the end");
  }

  /// Renders scrollable scrollsheet
  void renderListOfNextBuses(List<BothDirectionRouteWithTrips> buses) async {
    scrollSheetDotList.clear();
    nextBuses.clear();
    if (buses.length == 0) {
      setState(() {
        scrollsheetText = "No Buses Found";
      });
      return;
    }
    for (BothDirectionRouteWithTrips b in buses) {
      var directions = [];
      var destinationToTrip = new HashMap<String, Trip>();
      for (Trip t in b.Trips) {
        if (destinationToTrip.containsKey(patternHelper(t.Pattern))) {
          if (t.ExpectedCountdown <
              destinationToTrip[patternHelper(t.Pattern)].ExpectedCountdown) {
            destinationToTrip[patternHelper(t.Pattern)] = t;
          }
        } else {
          destinationToTrip[patternHelper(t.Pattern)] = t;
          directions.add(patternHelper(t.Pattern));
        }
      }
      BothDirectionRouteWithTrips bitrip =
          new BothDirectionRouteWithTrips("", []);
      bitrip.RouteNo = b.RouteNo;
      for (String s in directions) {
        destinationToTrip[s].RouteNo = b.RouteNo;
        bitrip.Trips.add(destinationToTrip[s]);
      }
      setState(() {
        nextBuses.add(bitrip);
        scrollSheetDotList.add(0);
      });
    }
  }

  ///
  /// Calls the Translink API and updates the bus locations on the map
  ///
  void updateBuses() async {
    setState(() {
      isLoading = true;
    });
    // Fetch buses around the user based on the user location
    LocationFetcher locationFetcher = new LocationFetcher();
    Future<List<Bus>> future = locationFetcher.fetchAllBuses();
    List<Bus> buses = await future;

    Future<List<Marker>> markersFuture = getBusList(buses);
    List<Marker> list = await markersFuture;

    // Sets the state to update the markers on the map
    setState(() {
      isLoading = false;
      _markers.clear();
      for (int i = 0; i < list.length; i++) {
        _markers[list[i].markerId.toString()] = list[i];
      }
    });
  }

  ///
  /// Fetches location and calls Translink API and updates bus stops on map
  ///
  void getLocationAndUpdateStops() async {
    Position locationData;
    try {
      locationData = await getLocation();
      setState(() {
        isLocationEnabled = true;
        scrollsheetText = "Searching For Buses...";
      });
    } catch (e) {
      setState(() {
        isLocationEnabled = false;
        scrollsheetText = "Location Services Disabled";
      });
      // User did not grant location permissions
      if (e.code != 'PERMISSION_DENIED') {
        throw e;
      }
    }
    if (zoomBool == true) {
      updateStops(
          //358
          locationData.latitude.toString(),
          locationData.longitude.toString());
    }
  }

  ///
  /// Calls the Translink API and updates the bus stops on the map
  ///
  void updateStops(String latitude, String longitude) async {
    StopFetcher stopFetcher = new StopFetcher();
    Future<List<Stop>> future = stopFetcher.stopFetcher(latitude, longitude);
    List<Stop> stops = await future;

    Future<List<Marker>> markersFuture = getStopList(stops);
    List<Marker> list = await markersFuture;

    // Sets the state to update the markers on the map
    setState(() {
      _markers.clear();
      for (int i = 0; i < list.length; i++) {
        _markers[list[i].markerId.toString()] = list[i];
      }
    });
  }

  void updateStopsForMap(double latitude1, double latitude2, double longitude1,
      double longitude2) async {
    _markers.clear();
    List<Stop> validStops = [];
    for (Stop s in listOfStops) {
      if (s.Latitude < latitude1 &&
          s.Latitude > latitude2 &&
          s.Longitude < longitude1 &&
          s.Longitude > longitude2) {
        validStops.add(s);
      }
    }
    Future<List<Marker>> markersFuture = getStopList(validStops);
    List<Marker> list = await markersFuture;

    // Sets the state to update the markers on the map
    setState(() {
      _markers.clear();
      for (int i = 0; i < list.length; i++) {
        _markers[list[i].markerId.toString()] = list[i];
      }
    });
  }

  String patternHelper(String s) {
    if (s.startsWith("E")) {
      return "EASTBOUND";
    } else if (s.startsWith("N")) {
      return "NORTHBOUND";
    } else if (s.startsWith("W")) {
      return "WESTBOUND";
    } else if (s.startsWith("S")) {
      return "SOUTHBOUND";
    }
  }

  String removeZeroes(String s) {
    while (s.substring(0, 1) == "0") {
      s = s.substring(1);
    }
    return s;
  }

  Future<ui.Image> load(String asset) async {
    ByteData data = await rootBundle.load(asset);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  GoogleMapController mapController;
  bool isLocationOnMapEnabled = false;
  SearchBarController<Stop> searchBarController = SearchBarController();

  ///
  /// Called when the map is first created
  ///
  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    mapController.setMapStyle(
        '[  {    "elementType": "geometry",    "stylers": [      {        "color": "#242f3e"      }    ]  },  {    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#746855"      }    ]  },  {    "elementType": "labels.text.stroke",    "stylers": [      {        "color": "#242f3e"      }    ]  },  {    "featureType": "administrative.locality",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#d59563"      }    ]  },  {    "featureType": "poi",    "stylers": [      {        "visibility": "off"      }    ]  },  {    "featureType": "poi",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#d59563"      }    ]  },  {    "featureType": "poi.park",    "stylers": [      {        "visibility": "on"      }    ]  },  {    "featureType": "poi.park",    "elementType": "geometry",    "stylers": [      {        "color": "#263c3f"      }    ]  },  {    "featureType": "poi.park",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#6b9a76"      }    ]  },  {    "featureType": "road",    "elementType": "geometry",    "stylers": [      {        "color": "#38414e"      }    ]  },  {    "featureType": "road",    "elementType": "geometry.stroke",    "stylers": [      {        "color": "#212a37"      },      {        "visibility": "simplified"      },      {        "weight": 2      }    ]  },  {    "featureType": "road",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#9ca5b3"      }    ]  },  {    "featureType": "road.highway",    "elementType": "geometry",    "stylers": [      {        "color": "#746855"      }    ]  },  {    "featureType": "road.highway",    "elementType": "geometry.stroke",    "stylers": [      {        "color": "#1f2835"      }    ]  },  {    "featureType": "road.highway",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#f3d19c"      }    ]  },  {    "featureType": "transit",    "stylers": [      {        "visibility": "off"      }    ]  },  {    "featureType": "transit",    "elementType": "geometry",    "stylers": [      {        "color": "#2f3948"      }    ]  },  {    "featureType": "transit.station",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#d59563"      }    ]  },  {    "featureType": "water",    "elementType": "geometry",    "stylers": [      {        "color": "#17263c"      }    ]  },  {    "featureType": "water",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#515c6d"      }    ]  },  {    "featureType": "water",    "elementType": "labels.text.stroke",    "stylers": [      {        "color": "#17263c"      }    ]  }]');
    // Find the current location of the user
    _currentLocation();
  }

// https://stackoverflow.com/questions/52569602/flutter-run-function-every-x-amount-of-seconds

  void _currentLocation() async {
    if (mapController == null) {
      return;
    }

    if (userLocation == null) {
      return;
    }

    final GoogleMapController controller = mapController;
//    Position currentLocation;
    try {
      setState(() {
        isLocationEnabled = true;
      });
//      currentLocation = await location.getLocation();
//      currentLocation = await getCurrentPosition(
////        locationPermissionLevel: GeolocationPermission.locationWhenInUse,
//      );
      setState(() {
        isLocationOnMapEnabled = true;
      });

      hasAnimated = true;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          bearing: 0,
          target: LatLng(userLocation.latitude, userLocation.longitude),
          zoom: 17.0,
        ),
      ));
    } on Exception {
      setState(() {
        isLocationEnabled = false;
        scrollsheetText = "Location Services Disabled";
      });
      userLocation = null;
    }
  }

  ///
  /// Builds the UI
  ///

  @override
  Widget build(BuildContext context) => MaterialApp(
          home: Scaffold(
        key: _scaffoldKey,
        body: Stack(children: <Widget>[
          GoogleMap(
            myLocationEnabled: isLocationOnMapEnabled,
            myLocationButtonEnabled: false,
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: const LatLng(49.2418584, -123.1401792),
              zoom: 14,
            ),
            polylines: Set<Polyline>.of(_mapPolylines.values),
            markers: _markers.values
                .where((marker) {
                  // Based on selected route, return true if marker is part of that route
                  if (selectedRouteNo == null || selectedPattern == null) {
                    return true;
                  }
                  if (marker.markerId.toString().split('!').length < 3) {
                    //hiding stop markers while getting buses
                    return false;
                  }
                  if (marker.markerId.toString().split('!')[1] ==
                          removeZeroes(selectedRouteNo) &&
                      marker.markerId
                              .toString()
                              .split('!')[2]
                              .substring(0, 1) ==
                          selectedPattern.substring(0, 1)) {
                    return true;
                  } else {
                    return false;
                  }
                })
                .toSet()
                .union(Set.from(selectedStop == null ? [] : [selectedStop])),
            //google map
            onTap: (LatLng a) {
              tappedIntoStop = false;
              if (searchBarController != null) {
                searchBarController.clear();
              }
              setState(() {
                if (nextBusesCopy != null && scrollSheetDotListCopy != null) {
                  nextBuses = nextBusesCopy;
                  scrollSheetDotList = scrollSheetDotListCopy;
                }
                if (isSelected[1] == true) {}
                _mapPolylines.clear();
              });
            },
            onCameraIdle: () {
              count--;
              print("ON MAP MOVE with count = " + count.toString());
              if (count <= 0) {
                tappedIntoStop = false;
                // moved into if statement to prevent on camera idle code on tap stop
                highlightedStopNo = null;
                setState(() {
                  if (nextBusesCopy != null && scrollSheetDotListCopy != null) {
                    nextBuses = nextBusesCopy;
                    scrollSheetDotList = scrollSheetDotListCopy;
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
            duration: Duration(milliseconds: 681),
            child: Align(
                alignment: Alignment.center,
                child: RichText(
                    text: TextSpan(
                        style: TextStyle(
                            fontWeight: FontWeight.w300,
                            fontStyle: FontStyle.normal,
                            fontSize: 18),
                        text: 'Zoom in to see stops'))),
          ),
          Visibility(
            visible: !showingSpecificBuses,
            child: Positioned(
              top: 110,
              right: 7,
              left: 7,
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  decoration: BoxDecoration(
                    color: getColorFromHex('cfd1d4'),
                    border: Border.all(color: Colors.black, width: 1.0),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: ToggleButtons(
                    fillColor: getColorFromHex('e8eaed'),
                    disabledColor: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    children: <Widget>[
                      Icon(Icons.directions_bus),
                      Icon(Icons.pin_drop),

                      //ImageIcon( new AssetImage('images/marker-north-h.png'), color: null, size: 160),
                    ],
                    onPressed: (int index) {
                      // Do some work (e.g. check sif the tap is valid)
                      vibrate();
                      if (nextBusesCopy != null &&
                          scrollSheetDotListCopy != null) {
                        nextBuses = nextBusesCopy;
                        scrollSheetDotList = scrollSheetDotListCopy;
                      }
                      // Do more work (e.g. respond to the tap)
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
                          if (buttonIndex == index) {
                            isSelected[buttonIndex] = true;
                          } else {
                            isSelected[buttonIndex] = false;
                          }
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
              top: 168,
              right: 7,
              left: 7,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  height: 50,
                  width: 50,
                  child: FittedBox(
                    child: FloatingActionButton(
                      onPressed: () {
                        _currentLocation();
                      },
                      child: Icon(
                        Icons.my_location,
                        size: 24,
                        color: Color.fromRGBO(255, 255, 255, 0.9),
                      ),
                      backgroundColor: Color.fromRGBO(255, 255, 255, 0.1),
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
              builder: (BuildContext context, myscrollController) {
                return Container(
                    color: Colors.deepOrangeAccent.withOpacity(0.0),
                    child: Stack(children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(0.0, 27.0, 0.0, 0.0),
                        color: getColorFromHex('e8eaed').withOpacity(0.99),
                        child: Stack(children: [
                          AnimatedOpacity(
                            opacity: nextBuses.length > 0 ? 1.0 : 0.0,
                            duration: Duration(milliseconds: 2),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(0, 15, 0, 0),
                              controller: myscrollController,
                              itemCount: nextBuses.length,
                              itemBuilder: (BuildContext context, int index) {
                                return ListTile(
                                  key: Key(nextBuses[index].RouteNo.toString()),
                                  title: Column(children: [
                                    CarouselSlider(
                                      options: CarouselOptions(
                                        onPageChanged: (carouselIndex, reason) {
                                          setState(() {
                                            scrollSheetDotList[index] =
                                                carouselIndex;
                                          });
                                        },
                                        height: 64.0,
                                        viewportFraction: 1.0,
                                      ),
                                      items: nextBuses[index].Trips.map((trip) {
                                        return Builder(
                                          builder: (BuildContext context) {
                                            return InkWell(
                                                onTap: () {
                                                  NextBusesForRouteAtStop
                                                      busFetcher =
                                                      new NextBusesForRouteAtStop();
                                                  Future<List<Trip>>
                                                      futureBuses = busFetcher
                                                          .busAtSingleStopFetcher(
                                                              trip.StopNo,
                                                              nextBuses[index]
                                                                  .RouteNo);
                                                  futureBuses
                                                      .then((List<Trip> value) {
                                                    final popup = BeautifulPopup
                                                        .customize(
                                                            context: _scaffoldKey
                                                                .currentContext,
                                                            build: (options) {
                                                              MyTemplate template = MyTemplate(
                                                                  options,
                                                                  removeZeroes(
                                                                      nextBuses[
                                                                              index]
                                                                          .RouteNo),
                                                                  patternHelper(
                                                                      trip.Pattern),
                                                                  trip.StopNo,
                                                                  value);
                                                              return template;
                                                            });
                                                    popup.show(
                                                      title: 'Example',
                                                      content: Container(
                                                        color: Colors.black12,
                                                        child: Text(
                                                            'This popup shows you how to customize your own BeautifulPopupTemplate.'),
                                                      ),
                                                      actions: [
                                                        popup.button(
                                                            label:
                                                                'Show buses on map',
                                                            onPressed: () {
                                                              showingSpecificBuses =
                                                                  true;
                                                              Navigator.of(
                                                                      _scaffoldKey
                                                                          .currentContext)
                                                                  .pop();
                                                              filterBuses(
                                                                  nextBuses[
                                                                          index]
                                                                      .RouteNo,
                                                                  trip.Pattern,
                                                                  trip.StopNo);
                                                            }),
                                                      ],
                                                    );
                                                  });
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
                                                      children: <Widget>[
                                                        Container(
                                                          width: 70,
                                                          margin:
                                                              const EdgeInsets
                                                                      .only(
                                                                  right: 0,
                                                                  left: 0),
                                                          child: Text(
                                                            removeZeroes(
                                                                nextBuses[index]
                                                                    .RouteNo),
                                                            textAlign: TextAlign
                                                                .center,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize:
                                                                  removeZeroes(nextBuses[index].RouteNo)
                                                                              .length <
                                                                          3
                                                                      ? 50
                                                                      : 35,
                                                              height: 1.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  getColorFromHex(
                                                                      '#10295D'),
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: <Widget>[
                                                              Container(
                                                                margin:
                                                                    const EdgeInsets
                                                                            .only(
                                                                        left:
                                                                            15),
                                                                child: Text(
                                                                  nextBuses[
                                                                          index]
                                                                      .Trips[scrollSheetDotList[
                                                                          index]]
                                                                      .Destination,
                                                                  textAlign:
                                                                      TextAlign
                                                                          .left,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    height: 1.0,
                                                                    color: getColorFromHex(
                                                                        '#024D7E'),
                                                                  ),
                                                                ),
                                                              ),
                                                              Container(
                                                                margin:
                                                                    const EdgeInsets
                                                                            .only(
                                                                        left:
                                                                            15),
                                                                child: Text(
                                                                  patternHelper(nextBuses[
                                                                              index]
                                                                          .Trips[scrollSheetDotList[
                                                                              index]]
                                                                          .Pattern) +
                                                                      " at \n" +
                                                                      nextBuses[
                                                                              index]
                                                                          .Trips[
                                                                              scrollSheetDotList[index]]
                                                                          .nextStop
                                                                          .toString(),
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
                                                                          FontWeight
                                                                              .w400,
                                                                      color: Colors
                                                                          .deepOrange),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          width: 83,
                                                          child: Text(
                                                            nextBuses[index]
                                                                    .Trips[scrollSheetDotList[
                                                                        index]]
                                                                    .ExpectedCountdown
                                                                    .toString() +
                                                                " min",
                                                            textAlign: TextAlign
                                                                .center,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: nextBuses[
                                                                              index]
                                                                          .Trips[
                                                                              scrollSheetDotList[index]]
                                                                          .ExpectedCountdown
                                                                          .toString()
                                                                          .length <
                                                                      3
                                                                  ? 24
                                                                  : 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              height: 1.0,
                                                              color:
                                                                  getColorFromHex(
                                                                      '#10295D'),
                                                            ),
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  ],
                                                ));
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
                                          .map((url) {
                                        int itemIndex = url.key;
                                        return Container(
                                          width: 6.0,
                                          height: 5.0,
                                          margin: EdgeInsets.symmetric(
                                              vertical: 2.0, horizontal: 2.0),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: scrollSheetDotList[index] ==
                                                    itemIndex
                                                ? Color.fromRGBO(0, 0, 0, 0.3)
                                                : Color.fromRGBO(0, 0, 0, 0.15),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    Divider(
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ]),
                                );
                              },
                            ),
                          ),
                          Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedOpacity(
                                      opacity:
                                          nextBuses.length == 0 ? 1.0 : 0.0,
                                      duration: Duration(milliseconds: 20),
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: RichText(
                                            text: TextSpan(
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w500,
                                                    fontStyle: FontStyle.normal,
                                                    fontSize: 19),
                                                text: scrollsheetText)),
                                      )),
                                  Visibility(
                                      visible: !isLocationEnabled,
                                      child: Flexible(
                                        child: Container(
                                            padding: EdgeInsets.fromLTRB(
                                                35, 10, 30, 0),
                                            child: RichText(
                                                text: TextSpan(
                                                    recognizer:
                                                        TapGestureRecognizer()
                                                          ..onTap = () {
                                                            AppSettings
                                                                .openLocationSettings();
                                                          },
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w300,
                                                        fontStyle:
                                                            FontStyle.normal,
                                                        fontSize: 16),
                                                    text: !tappedIntoStop
                                                        ? "Please allow Transit to access your location to improve your experience"
                                                        : ""))),
                                      )),
                                ]),
                          ),
                        ]),
                      ),
                      Positioned(
                        right: 70.0,
                        child: Container(
                          height: 24,
                          width: 24,
                          child: FittedBox(
                            child: FloatingActionButton(
                              onPressed: () {
                                if (!tappedIntoStop) {
                                  updateNextBusesForAllNearbyStops();
                                }
                                if (isSelected[0] == true) {
                                  updateBuses();
                                }
                              },
                              child: Icon(
                                Icons.refresh,
                                size: 50,
                                color: Color.fromRGBO(255, 255, 255, 0.9),
                              ),
                              backgroundColor: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                          right: 0.0,
                          child: Container(
                            width: 65.0,
                            height: 25.0,
                            decoration: new BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.rectangle,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8.0))),
                            child: Align(
                                alignment: Alignment.center,
                                child: RichText(
                                    text: TextSpan(children: [
                                  WidgetSpan(
                                      child: isLoading
                                          ? SizedBox(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                backgroundColor: Colors.orange,
                                              ),
                                              height: 15,
                                              width: 15,
                                            )
                                          : Icon(
                                              Icons.rss_feed,
                                              size: 16,
                                            )),
                                  !isLoading
                                      ? TextSpan(
                                          style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontStyle: FontStyle.normal,
                                              fontSize: 13),
                                          text: ((30 - timeDifference.inSeconds)
                                                  .toString()) +
                                              " sec")
                                      : TextSpan(text: ""),
                                ]))),
                          )),
                    ]));
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
              duration: Duration(milliseconds: 300),
              child: Visibility(
                child: Container(
                    decoration: BoxDecoration(
                  color: Colors.white,
                )),
                visible: isSearching,
              ),
            ),
          ),
          Visibility(
            visible: !showingSpecificBuses,
            child: Container(
                child: TransitSearchBar<Stop>(
              searchBarController: searchBarController,
              minimumChars: 1,
              hintText: "Search for stops",
              textStyle: new TextStyle(
                fontSize: 18,
              ),
              shrinkWrap: true,
              placeHolder: SizedBox.shrink(),
              contentPadding: EdgeInsets.all(0),
              searchBarPadding: EdgeInsets.fromLTRB(10, 20, 10, 0),
              searchBarStyle: SearchBarStyle(
                searchBarHeight: 52,
                backgroundColor: getColorFromHex('e8eaed'),
                padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                borderRadius: BorderRadius.circular(10),
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
                print(error.stackTrace.toString());
                return Text("no error");
              },
              emptyWidget: Align(
                alignment: Alignment.center,
                child: RichText(
                    text: TextSpan(
                        style: TextStyle(
                            color: Colors.black87,
                            fontStyle: FontStyle.normal,
                            fontSize: 18),
                        text: 'No Stops Found')),
              ),
              onItemFound: (Stop post, int index) {
                return ListTile(
                  title: Text(post.StopNo.toString()),
                  subtitle: Text(post.Name),
                  onTap: () {
                    setState(() {
                      //makes sure not to clone the wrong list
                      if (!tappedIntoStop) {
                        nextBusesCopy =
                            List<BothDirectionRouteWithTrips>.from(nextBuses);
                        scrollSheetDotListCopy =
                            List<dynamic>.from(scrollSheetDotList);
                      }
                      tappedIntoStop = true;
                      isSelected = [false, true];
                      BusAtSingleStopFetcher busFetcher =
                          new BusAtSingleStopFetcher();
                      Future<List<BothDirectionRouteWithTrips>> futureBuses =
                          busFetcher.busAtSingleStopFetcher(
                              post, post.StopNo.toString());
                      futureBuses
                          .then((List<BothDirectionRouteWithTrips> value) {
                        print(value.toString());
                        renderListOfNextBuses(value);
                      });
                    });
                    searchBarController.clear();
                    CameraPosition _kLake = CameraPosition(
                        target: LatLng(post.Latitude, post.Longitude),
                        zoom: 18);
                    highlightedStopNo = post.StopNo;
                    count = 2;
                    updateStops(
                        post.Latitude.toString(), post.Longitude.toString());
                    mapController
                        .animateCamera(CameraUpdate.newCameraPosition(_kLake));
                  },
                );
              },
            )),
          ),
          Visibility(
            visible: showingSpecificBuses,
            child: Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  height: 70,
                  width: 70,
                  child: FittedBox(
                    child: FloatingActionButton(
                      onPressed: () {
                        showingSpecificBuses = false;
                        selectedRouteNo = null;
                        selectedStop = null;
                        selectedPattern = null;
                      },
                      child: Icon(
                        Icons.arrow_back_ios,
                        size: 25,
                        color: Color.fromRGBO(255, 255, 255, 0.85),
                      ),
                      backgroundColor: Color.fromRGBO(255, 255, 255, 0.25),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ));

  void showZoomInIfNeeded() {
    mapController.getZoomLevel().then((value) {
      if (value > 15) {
        zoomBool = false;
        mapController.getVisibleRegion().then((value) {
          updateStopsForMap(value.northeast.latitude, value.southwest.latitude,
              value.northeast.longitude, value.southwest.longitude);
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
      MarkerHelper.createCustomMarkerBitmapNoText(image, 75, 75)
          .then((bitmapDescriptor) {
        double latitude;
        double longitude;
        String stopName;
        print(
            "88888888888888888888888888888888888888888888888888888888888888888888");
        print(routeNo + " " + pattern + " " + stopNo);
        for (Stop s in listOfStops) {
          if (s.StopNo.toString() == stopNo) {
            latitude = s.Latitude;
            longitude = s.Longitude;
            stopName = s.Name;
            print(
                "ASDFDASDYUIFOAKJSHGEFTYUIJKNBGVSFTYUIJKNGVFRT6Y7U8IESJEUHHHHHHU888888888888888888888888888");
            print(latitude.toString() +
                " " +
                longitude.toString() +
                " " +
                stopName);
            break;
          }
        }
        if (stopName == null) {
          return;
        }
        final marker = Marker(
            markerId: MarkerId(stopNo.toString()),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(
              title: stopName.toString(),
              snippet: stopNo.toString(),
            ),
            icon: bitmapDescriptor);
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
/// Given a HEX color, return in a format that the system understands
///
Color getColorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll('#', '');

  if (hexColor.length == 6) {
    hexColor = 'FF' + hexColor;
  }

  return Color(int.parse(hexColor, radix: 16));
}

class Post {
  final String title;
  final String description;

  Post(this.title, this.description);
}
