import 'package:flutter/material.dart';

import 'fetchers/NextBusesForRouteAtStop.dart';
import 'models/Trip.dart';

Color _colorFromHex(String hexColor) {
  final String h = hexColor.toUpperCase().replaceAll('#', '');
  return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
}

class WaitTimesPopup extends StatefulWidget {
  final String routeNo;
  final String pattern;
  final String stopNo;

  const WaitTimesPopup({
    super.key,
    required this.routeNo,
    required this.pattern,
    required this.stopNo,
  });

  @override
  State<WaitTimesPopup> createState() => _WaitTimesPopupState();
}

class _WaitTimesPopupState extends State<WaitTimesPopup> {
  List<Trip> trips = [];

  String _timeFormatter(String input) {
    final String time = input.split(' ')[0];
    if (time.contains('am')) {
      return '${time.substring(0, time.length - 2)} AM';
    } else {
      return '${time.substring(0, time.length - 2)} PM';
    }
  }

  @override
  void initState() {
    super.initState();
    NextBusesForRouteAtStop()
        .busAtSingleStopFetcher(widget.stopNo, widget.routeNo)
        .then((value) {
      if (mounted) {
        setState(() {
          trips = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.only(top: 36.0),
        color: _colorFromHex('#024D7E'),
        child: Column(
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back_ios, color: Colors.white70),
                      Text('Back', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: widget.routeNo,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  fontSize: 100,
                ),
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: widget.pattern,
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w800,
                  fontSize: 25,
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.transparent,
                margin: const EdgeInsets.all(12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: _colorFromHex('#EEEEEE'),
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  child: Scrollbar(
                    child: ListView.builder(
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true,
                      itemCount: trips.length,
                      padding: const EdgeInsets.fromLTRB(8.0, 16.0, 8.0, 16.0),
                      itemBuilder: (context, index) {
                        final trip = trips[index];
                        return ListTile(
                          title: Row(
                            children: [
                              SizedBox(
                                width: 130,
                                child: RichText(
                                  textAlign: TextAlign.left,
                                  text: TextSpan(
                                    text: _timeFormatter(
                                        trip.ExpectedLeaveTime ?? ''),
                                    style: TextStyle(
                                      color: _colorFromHex('#0d2036'),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              RichText(
                                overflow: TextOverflow.fade,
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  text: 'TO ${trip.Destination ?? ''}',
                                  style: TextStyle(
                                    color: _colorFromHex('#0d2036'),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
