import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transitapp/fetchers/BusAtSingleStopFetcher.dart';
import 'package:transitapp/models/Bus.dart';
import 'package:transitapp/fetchers/LocationFetcher.dart';
import 'package:location/location.dart';
import 'package:transitapp/util/MarkerHelper.dart';
import 'package:vibrate/vibrate.dart';

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
  @override
  _TransitAppState createState() => _TransitAppState();
}

///
/// Contains the state of the home screen
/// The widget is rendered based on the state defined here
///
class _TransitAppState extends State<TransitApp> {
  Map<PolylineId, Polyline> _mapPolylines = {};
  Timer timer;
  Timer timerShort;
  List<bool> isSelected = [true, false];
  List<Trip> listOfTripsThatWeCreatedJustSoWeKnowItWorks = [];
  List<Trip> nextBuses = [];

  bool zoomBool = false;

  void vibrate() async {
    bool canVibrate = await Vibrate.canVibrate;
    canVibrate ? Vibrate.feedback(FeedbackType.medium) : null;
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(
        Duration(seconds: 30), (Timer t) => timerIfSelectedHelper());
    timerShort = Timer.periodic(
        Duration(seconds: 2), (Timer t) => timerIfSelectedHelperShort());
  }

  void timerIfSelectedHelperShort() {
    if (isSelected[0] == true)
      setState(() {
        for (String key in _markers.keys) {
          final marker = Marker(
              onTap: _markers[key].onTap,
              markerId: _markers[key].markerId,
              position: LatLng(_markers[key].position.latitude + 0.1,
                  _markers[key].position.longitude + 0.1),
              infoWindow: _markers[key].infoWindow,
              icon: _markers[key].icon);
          _markers[key] = marker;
          print("66");
          //The Great Migration
        }
      });
  }

  void timerIfSelectedHelper() {
    if (isSelected[0] == true) {
      updateBuses();
    }
  }

  void dispose() {
    timer?.cancel();
    timerShort?.cancel();
    super.dispose();
  }

// Markers of buses to display on the home screen (vehicle ID to marker)
  final Map<String, Marker> _markers = {};

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
          onTap: () {
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
          markerId: MarkerId(bus.VehicleNo),
          position: LatLng(bus.Latitude, bus.Longitude),
          infoWindow: InfoWindow(
            title: bus.RouteNo,
            snippet: bus.Pattern,
          ),
          icon: bitmapDescriptor);
      l.add(marker);
    }
    print("Got markers list");
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
      bitmapFutures.add(MarkerHelper.createCustomMarkerBitmapNoText(image));
//      print("Added bus with route " + bus.RouteNo.toString());
    }
    print("Got markers list");

    List<BitmapDescriptor> futures = await Future.wait(bitmapFutures);
    for (var i = 0; i < stops.length; i++) {
      Stop stop = stops[i];
//      print("Parsing bus with route " + bus.RouteNo.toString());
      BitmapDescriptor bitmapDescriptor = futures[i];
      // TODO: Customize marker
      // https://stackoverflow.com/questions/54041830/how-to-add-extra-into-text-into-flutter-google-map-custom-marker
      final marker = Marker(
          onTap: () {
            setState(() {
              BusAtSingleStopFetcher busFetcher = new BusAtSingleStopFetcher();
              Future<List<BothDirectionRouteWithTrips>> futureBuses = busFetcher
                  .busAtSingleStopFetcher(stop, stop.StopNo.toString());
              futureBuses.then((List<BothDirectionRouteWithTrips> value) {
                List<BothDirectionRouteWithTrips> buses = value;
                for (BothDirectionRouteWithTrips t in value) {
                  int count = 0;
                  for (Trip trip in t.Trips) {
                    trip.RouteNo = t.RouteNo;
                    nextBuses.add(trip);
                    count++;
                  }
                }
              });
            });
          },
          markerId: MarkerId(stop.StopNo.toString()),
          position: LatLng(stop.Latitude, stop.Longitude),
          infoWindow: InfoWindow(
            title: stop.Name.toString(),
            snippet: stop.AtStreet,
          ),
          icon: bitmapDescriptor);
      l.add(marker);
    }
    return l;
  }

  ///
  /// Calls the Translink API and updates the bus locations on the map
  ///
  void updateBuses() async {
    // Fetch buses around the user based on the user location
    LocationFetcher locationFetcher = new LocationFetcher();
    Future<List<Bus>> future = locationFetcher.fetchAllBuses();
    List<Bus> buses = await future;

    Future<List<Marker>> markersFuture = getBusList(buses);
    List<Marker> list = await markersFuture;
    print("Done getting markers list");

    // Sets the state to update the markers on the map
    setState(() {
      _markers.clear();
      print("230");
      for (int i = 0; i < list.length; i++) {
        _markers[list[i].markerId.toString()] = list[i];
        print("236");
      }
    });
  }

  ///
  /// Fetches location and calls Translink API and updates bus stops on map
  ///
  void getLocationAndUpdateStops() async {
    Location location = new Location();
    LocationData locationData;
    try {
      locationData = await location.getLocation();
    } catch (e) {
      // User did not grant location permissions
      if (e.code != 'PERMISSION_DENIED') {
        throw e;
      }
    }
    updateStops(
        //358
        locationData.latitude.toString(),
        locationData.longitude.toString());
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
    print("Done getting markers list");

    // Sets the state to update the markers on the map
    setState(() {
      _markers.clear();
      print("274");
      for (int i = 0; i < list.length; i++) {
        _markers[list[i].markerId.toString()] = list[i];
        print("277");
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

  ///
  /// Called when the map is first created
  ///
  Future<void> _onMapCreated(GoogleMapController controller) async {
    Trip t = new Trip();
    t.Pattern = " .";
    t.LastUpdate = " o";
    t.ExpectedCountdown = 0;
    t.Destination = "Hogwarts";
    listOfTripsThatWeCreatedJustSoWeKnowItWorks.add(t);

    mapController = controller;
    mapController.setMapStyle(
        '[  {    "elementType": "geometry",    "stylers": [      {        "color": "#242f3e"      }    ]  },  {    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#746855"      }    ]  },  {    "elementType": "labels.text.stroke",    "stylers": [      {        "color": "#242f3e"      }    ]  },  {    "featureType": "administrative.locality",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#d59563"      }    ]  },  {    "featureType": "poi",    "stylers": [      {        "visibility": "off"      }    ]  },  {    "featureType": "poi",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#d59563"      }    ]  },  {    "featureType": "poi.park",    "stylers": [      {        "visibility": "on"      }    ]  },  {    "featureType": "poi.park",    "elementType": "geometry",    "stylers": [      {        "color": "#263c3f"      }    ]  },  {    "featureType": "poi.park",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#6b9a76"      }    ]  },  {    "featureType": "road",    "elementType": "geometry",    "stylers": [      {        "color": "#38414e"      }    ]  },  {    "featureType": "road",    "elementType": "geometry.stroke",    "stylers": [      {        "color": "#212a37"      },      {        "visibility": "simplified"      },      {        "weight": 2      }    ]  },  {    "featureType": "road",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#9ca5b3"      }    ]  },  {    "featureType": "road.highway",    "elementType": "geometry",    "stylers": [      {        "color": "#746855"      }    ]  },  {    "featureType": "road.highway",    "elementType": "geometry.stroke",    "stylers": [      {        "color": "#1f2835"      }    ]  },  {    "featureType": "road.highway",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#f3d19c"      }    ]  },  {    "featureType": "transit",    "stylers": [      {        "visibility": "off"      }    ]  },  {    "featureType": "transit",    "elementType": "geometry",    "stylers": [      {        "color": "#2f3948"      }    ]  },  {    "featureType": "transit.station",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#d59563"      }    ]  },  {    "featureType": "water",    "elementType": "geometry",    "stylers": [      {        "color": "#17263c"      }    ]  },  {    "featureType": "water",    "elementType": "labels.text.fill",    "stylers": [      {        "color": "#515c6d"      }    ]  },  {    "featureType": "water",    "elementType": "labels.text.stroke",    "stylers": [      {        "color": "#17263c"      }    ]  }]');
    // Find the current location of the user
    Location location = new Location();
    LocationData locationData;
    try {
      locationData = await location.getLocation();
    } catch (e) {
      // User did not grant location permissions
      if (e.code != 'PERMISSION_DENIED') {
        throw e;
      }
    }

    if (locationData == null) {
      // User has denied location permissions
      // TODO: Use default Vancouver location
    }
    debugPrint('Found location: ' +
        locationData.latitude.toString() +
        ', ' +
        locationData.longitude.toString());

    // TODO: Update the markers on a regular basis
    //isSelected[0] == false
    if (isSelected[0] == false) {
      updateBuses();
    } else {
      updateStops(
          locationData.latitude.toString(), locationData.longitude.toString());
      StopFetcher stopFetcher = new StopFetcher();
      Future<List<Stop>> future = stopFetcher.stopFetcher(
          locationData.latitude.toString(), locationData.longitude.toString());
      List<Stop> stops = await future;
      BusAtStopFetcher busFetcher = new BusAtStopFetcher();
      Future<List<BothDirectionRouteWithTrips>> futureBuses = busFetcher
          .busFetcher(stops, locationData.latitude, locationData.longitude);
      List<BothDirectionRouteWithTrips> buses = await futureBuses;
      for (BothDirectionRouteWithTrips t in buses) {
        t.Trips[0].RouteNo = t.RouteNo;
        nextBuses.add(t.Trips[0]);
      }
    }
  }

// https://stackoverflow.com/questions/52569602/flutter-run-function-every-x-amount-of-seconds

  ///
  /// Builds the UI
  ///

  @override
  Widget build(BuildContext context) => MaterialApp(
          home: Scaffold(
        body: Stack(children: <Widget>[
          GoogleMap(
            myLocationEnabled: true,
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: const LatLng(49.2418584, -123.1401792),
              zoom: 14,
            ),
            polylines: Set<Polyline>.of(_mapPolylines.values),
            markers: _markers.values.toSet(),
            onTap: (LatLng a) {
              var abasdf = a;
              setState(() {
                _mapPolylines.clear();
              });
            },
            onCameraIdle: () {
              if (isSelected[0] == false) {
                mapController.getZoomLevel().then((value) {
                  if (value > 15) {
                    zoomBool = false;
                    mapController.getVisibleRegion().then((value) {
                      double lng = (value.northeast.longitude +
                              value.southwest.longitude) /
                          2;
                      double lat = (value.northeast.latitude +
                              value.southwest.latitude) /
                          2;
                      updateStops(lat.toString(), lng.toString());
                    });
                  } else {
                    setState(() {
                      _markers.clear();
                      zoomBool = true;
                    });
                  }
                });
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
          Positioned(
            top: 35,
            right: 15,
            left: 15,
            child: Container(
              color: Colors.white,
              child: Row(
                children: <Widget>[
                  IconButton(
                    splashColor: Colors.grey,
                    icon: Icon(Icons.menu),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      cursorColor: Colors.black,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.go,
                      decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 15),
                          hintText: "Search..."),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 100,
            right: 15,
            left: 15,
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1.0),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: ToggleButtons(
                  fillColor: Colors.white,
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
                    // Do more work (e.g. respond to the tap)
                    if (index == 0) {
                      updateBuses();
                    } else {
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
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.8,
            builder: (BuildContext context, myscrollController) {
              return Container(
                color: Colors.white,
                child: Stack(children: [
                  AnimatedOpacity(
                    opacity: nextBuses.length > 0 ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 2),
                    child: ListView.builder(
                      controller: myscrollController,
                      itemCount: nextBuses.length,
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                            title: Column(
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Container(
                                  width: 60,
                                  margin:
                                      const EdgeInsets.only(right: 0, left: 0),
                                  child: Text(
                                    removeZeroes(nextBuses[index].RouteNo),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 28,
                                        height: 1.0,
                                        color: Colors.black),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Container(
                                        margin: const EdgeInsets.only(left: 5),
                                        child: Text(
                                          nextBuses[index].Destination,
                                          textAlign: TextAlign.left,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            height: 1.0,
                                            color: getColorFromHex('#024D7E'),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: 5),
                                        child: Text(
                                          patternHelper(
                                                  nextBuses[index].Pattern) +
                                              " at \n" +
                                              nextBuses[index]
                                                  .nextStop
                                                  .toString(),
                                          textAlign: TextAlign.left,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 15,
                                              height: 1.0,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.deepOrange),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 80,
                                  child: Text(
                                    nextBuses[index]
                                            .ExpectedCountdown
                                            .toString() +
                                        " min",
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 22,
                                        height: 1.0,
                                        color: Colors.black),
                                  ),
                                )
                              ],
                            ),
                            Divider(
                              color: Theme.of(context).primaryColor,
                            ),
                          ],
                        ));
                      },
                    ),
                  ),
                  AnimatedOpacity(
                      opacity: nextBuses.length == 0 ? 1.0 : 0.0,
                      duration: Duration(milliseconds: 2),
                      child: Align(
                        alignment: Alignment.center,
                        child: RichText(
                            text: TextSpan(
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.normal,
                                    fontSize: 19),
                                text: 'No buses found near you')),
                  ))
                ]),
              );
            },
          ),
        ]),
      ));
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
