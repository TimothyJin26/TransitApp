import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:flutter/material.dart';
import 'models/BothDirectionRouteWithTrips.dart';
import 'transit_util.dart';

class RouteTile extends StatelessWidget {
  final BothDirectionRouteWithTrips route;
  final int dotIndex;
  final bool darkModeOn;
  final void Function(int dotIndex) onDotChanged;
  final Future<void> Function(String routeNo, String pattern, String stopNo) onTripTap;

  const RouteTile({
    super.key,
    required this.route,
    required this.dotIndex,
    required this.darkModeOn,
    required this.onDotChanged,
    required this.onTripTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key(route.RouteNo.toString()),
      title: Column(children: [
        CarouselSlider(
          options: CarouselOptions(
            onPageChanged: (index, _) => onDotChanged(index),
            height: 64.0,
            viewportFraction: 1.0,
          ),
          items: route.Trips.map((trip) {
            return Builder(
              builder: (context) => InkWell(
                onTap: () => onTripTap(
                  route.RouteNo,
                  trip.Pattern ?? '',
                  trip.StopNo ?? '',
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 70,
                      child: Text(
                        removeZeroes(route.RouteNo),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: removeZeroes(route.RouteNo).length < 3 ? 50 : 35,
                          height: 1.0,
                          fontWeight: FontWeight.w700,
                          color: darkModeOn ? Colors.white70 : getColorFromHex('#10295D'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(left: 15),
                            child: Text(
                              route.Trips[dotIndex].Destination ?? '',
                              textAlign: TextAlign.left,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                                color: darkModeOn ? Colors.white70 : getColorFromHex('#024D7E'),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 15),
                            child: Text(
                              '${patternHelper(route.Trips[dotIndex].Pattern ?? '')} at \n${route.Trips[dotIndex].nextStop ?? ''}',
                              textAlign: TextAlign.left,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.0,
                                fontWeight: FontWeight.w400,
                                color: getColorFromHex('1bab65'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 83,
                      child: Text(
                        '${route.Trips[dotIndex].ExpectedCountdown ?? 0} min',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: (route.Trips[dotIndex].ExpectedCountdown?.toString().length ?? 1) < 3 ? 24 : 20,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          color: darkModeOn ? Colors.white70 : getColorFromHex('#10295D'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: route.Trips.asMap().entries.map((entry) {
            return Container(
              width: 6.0,
              height: 5.0,
              margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotIndex == entry.key
                    ? (darkModeOn
                        ? const Color.fromRGBO(255, 255, 255, 0.3)
                        : const Color.fromRGBO(0, 0, 0, 0.3))
                    : (darkModeOn
                        ? const Color.fromRGBO(255, 255, 255, 0.15)
                        : const Color.fromRGBO(0, 0, 0, 0.15)),
              ),
            );
          }).toList(),
        ),
        Divider(color: Theme.of(context).primaryColor),
      ]),
    );
  }
}
