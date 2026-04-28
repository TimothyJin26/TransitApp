import 'package:flutter/material.dart';
import 'package:transitapp/util/TransitUtil.dart';

import 'fetchers/NextBusesForRouteAtStop.dart';
import 'models/Trip.dart';

class WaitTimesPopup extends StatefulWidget {
  final String routeNo;
  final String pattern;
  final String stopNo;
  final bool isDarkMode;

  const WaitTimesPopup({
    super.key,
    required this.routeNo,
    required this.pattern,
    required this.stopNo,
    this.isDarkMode = false,
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

  static const _acronyms = {'UBC', 'SFU', 'VCC', 'YVR', 'BCIT', 'NW'};

  String _toTitleCase(String s) {
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (_acronyms.contains(word)) return word;
      return word.split('-').map((part) {
        if (part.isEmpty) return part;
        if (_acronyms.contains(part)) return part;
        return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      }).join('-');
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = widget.isDarkMode;
    final headerBg = dark ? colorFromHex('1b2336') : colorFromHex('#024D7E');
    final listBg = dark ? colorFromHex('252d3d') : Colors.white;
    final textColor = dark ? Colors.white70 : colorFromHex('#0d2036');
    final dividerColor = dark
        ? Colors.white.withAlpha(20)
        : Colors.black.withAlpha(18);

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.only(top: 36.0),
        color: headerBg,
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
                    color: listBg,
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : trips.isEmpty
                          ? Center(
                              child: Text('No upcoming departures',
                                  style: TextStyle(color: textColor)))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(24.0),
                              child: Scrollbar(
                                child: ListView.separated(
                                  scrollDirection: Axis.vertical,
                                  shrinkWrap: true,
                                  itemCount: _visibleCount < trips.length
                                      ? _visibleCount + 1
                                      : trips.length,
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  separatorBuilder: (context, index) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: dividerColor,
                                    ),
                                  ),
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
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 90,
                                            child: Text(
                                              trip.ExpectedLeaveTime ?? '',
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              _toTitleCase(trip.Destination ?? ''),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          if (isLive)
                                            const Icon(Icons.rss_feed,
                                                size: 16,
                                                color: Color(0xFF1bab65))
                                          else
                                            const SizedBox.shrink(),
                                        ],
                                      ),
                                    );
                                  },
                                ),
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
