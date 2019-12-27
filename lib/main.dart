import 'dart:typed_data';
import 'dart:ui'as ui;
import 'package:flutter/services.dart' show rootBundle;


import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'Bus.dart';
import 'LocationFetcher.dart';
import 'package:location/location.dart';


void main() => runApp(MyApp());

/// Home screen of the transit app
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();

}

/// Contains the state of the home screen
/// The widget is rendered based on the state defined here
class _MyAppState extends State<MyApp> {
  // Markers of buses to display on the home screen (vehicle ID to marker)
  final Map<String, Marker> _markers = {};

  // Color of the marker
  final String colorOfMarker = "blue";

  // Calls the Translink API and updates the bus locations on the map
  void updateMarkers() async {
    // Fetch buses around the user based on the user location
    LocationFetcher locationFetcher = new LocationFetcher();
    Future<List<Bus>> future = locationFetcher.fetchAllBuses();
    List<Bus> buses = await future;
    List<Marker> list = [];

    for (int i = 0; i<buses.length; i++) {
      Bus pottao = buses[i];
      BitmapDescriptor bitmapDescriptor = await createCustomMarkerBitmap(pottao.RouteNo);

      // TODO: Customize marker
      // https://stackoverflow.com/questions/54041830/how-to-add-extra-into-text-into-flutter-google-map-custom-marker
      final marker = Marker(
          markerId: MarkerId(pottao.VehicleNo),
          position: LatLng(pottao.Latitude, pottao.Longitude),
          infoWindow: InfoWindow(
            title: pottao.RouteNo,
            snippet: pottao.Pattern,

          ),
          icon: bitmapDescriptor

      );
      list.add(marker);
    }

    // Sets the state to update the markers on the map
    setState(() {
      _markers.clear();
      for(int i=0; i<list.length;i++) {
        _markers[list[i].markerId.toString()] = list[i];
      }
    });
  }
  Future<ui.Image> load(String asset) async {
    ByteData data = await rootBundle.load(asset);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  Future<BitmapDescriptor> createCustomMarkerBitmap(String title) async {
    TextSpan span = new TextSpan(
      style: new TextStyle(
        color: Colors.white,
        fontSize: 40.0,
        fontWeight: FontWeight.bold,
      ),
      text: title,
    );

    TextPainter tp = new TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    int width = 100;
    int height = 100;

    ui.PictureRecorder recorder = new ui.PictureRecorder();
    Canvas c = new Canvas(recorder);
    Rect oval = Rect.fromLTWH(
        0,
        0,
        width+0.0,
        height+0.0
    );

    // Add image
    // TODO: Change icon depending on bus direction
    ui.Image image = await load('images/bus-marker-north.png');

    // Alternatively use your own method to get the image

    paintImage(canvas: c, image: image, rect: oval, fit: BoxFit.fitWidth);

    tp.layout();
    tp.paint(c, new Offset((width-tp.width)/2, 32));

    /* Do your painting of the custom icon here, including drawing text, shapes, etc. */


    /*like a bad alexa*/ui.Picture p = recorder.endRecording();
    ByteData pngBytes =
    await (await p.toImage(width, height))
        .toByteData(format: ui.ImageByteFormat.png);

    Uint8List data = Uint8List.view(pngBytes.buffer);

    return BitmapDescriptor.fromBytes(data);
  }


  // Called when the map is first created
  Future<void> _onMapCreated(GoogleMapController controller) async {
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
    debugPrint('Found location: ' + locationData.latitude.toString() + ', ' + locationData.longitude.toString());

    // TODO: Update the markers on a regular basis
    updateMarkers();
  }

  // TODO: Call the update markers on a regular basis
  // https://stackoverflow.com/questions/52569602/flutter-run-function-every-x-amount-of-seconds

  // Builds the view
  @override
  Widget build(BuildContext context) =>
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Locations of potatoes'),
            backgroundColor: Colors.green[700],
          ),
          body: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: const LatLng(49.2418584, -123.1401792),
              zoom: 11.5,
            ),
            markers: _markers.values.toSet(),
          ),
        ),
      );
}
