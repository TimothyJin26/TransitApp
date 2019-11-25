import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transitapp/RouteLink.dart';
import 'Bus.dart';
import 'LocationFetcher.dart';
import 'package:location/location.dart';


void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Map<String, Marker> _markers = {};
  final String colorOfMarker = "blue";

  Future<void> _onMapCreated(GoogleMapController controller) async {
    var location = new Location();
    LocationData locationData = await location.getLocation();
    debugPrint('Found location: ' + locationData.latitude.toString() + ', ' + locationData.longitude.toString());

    LocationFetcher x = new LocationFetcher();
    Future<List<Bus>> future = x.busFetcherBasedOnLocation(
        locationData.latitude.toString(),
        locationData.longitude.toString());
    List<Bus> buses = await future;

    setState(() {
      _markers.clear();
      for (int i = 0; i<buses.length; i++) {
        Bus pottao = buses[i];

        final marker = Marker(
          markerId: MarkerId(pottao.VehicleNo),
          position: LatLng(pottao.Latitude, pottao.Longitude),
          infoWindow: InfoWindow(
            title: pottao.RouteNo,
            snippet: pottao.Pattern,
          ),
        );
        _markers[pottao.VehicleNo] = marker;
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Google Office Locations'),
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
