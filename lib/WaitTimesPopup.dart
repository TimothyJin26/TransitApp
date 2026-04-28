import 'package:flutter/material.dart';
import 'package:transitapp/util/TransitUtil.dart';

import 'fetchers/NextBusesForRouteAtStop.dart';
import 'models/Trip.dart';

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

const _pageSize = 15;

class _WaitTimesPopupState extends State<WaitTimesPopup> {
  List<Trip> trips = [];
  bool loading = true;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    NextBusesForRouteAtStop()
        .busAtSingleStopFetcher(widget.stopNo, widget.routeNo, widget.pattern)
        .then((value) {
      if (mounted) {
        setState(() {
          trips = value;
          loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.only(top: 36.0),
        color: colorFromHex('#024D7E'),
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
                    color: colorFromHex('#EEEEEE'),
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : trips.isEmpty
                          ? const Center(child: Text('No upcoming departures'))
                          : Scrollbar(
                              child: ListView.builder(
                                scrollDirection: Axis.vertical,
                                shrinkWrap: true,
                                itemCount: _visibleCount < trips.length
                                    ? _visibleCount + 1  // +1 for "Load more" button
                                    : trips.length,
                                padding: const EdgeInsets.fromLTRB(8.0, 16.0, 8.0, 16.0),
                                itemBuilder: (context, index) {
                                  if (index == _visibleCount) {
                                    return TextButton(
                                      onPressed: () => setState(() {
                                        _visibleCount += _pageSize;
                                      }),
                                      child: const Text('Load more'),
                                    );
                                  }
                                  final trip = trips[index];
                                  final isLive = trip.LastUpdate != null &&
                                      trip.LastUpdate!.isNotEmpty;
                                  return ListTile(
                                    title: Row(
                                      children: [
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            trip.ExpectedLeaveTime ?? '',
                                            style: TextStyle(
                                              color: colorFromHex('#0d2036'),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${trip.Destination ?? ''}',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colorFromHex('#0d2036'),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        if (isLive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1bab65),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'LIVE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
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
