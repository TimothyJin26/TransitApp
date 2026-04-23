import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:flutter/material.dart';
import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Trip.dart';
import 'package:transitapp/util/TransitUtil.dart';

class BusTile extends StatelessWidget {
  final BothDirectionRouteWithTrips route;
  final int carouselIndex;
  final bool isDarkMode;
  final void Function(int) onCarouselChanged;
  final void Function(String pattern, String stopNo) onTap;

  const BusTile({
    super.key,
    required this.route,
    required this.carouselIndex,
    required this.isDarkMode,
    required this.onCarouselChanged,
    required this.onTap,
  });

  Widget _buildSlide(Trip trip) {
    final Trip activeTrip = route.Trips[carouselIndex];
    final String routeNo = removeLeadingZeros(route.RouteNo);
    return InkWell(
      onTap: () => onTap(trip.Pattern ?? '', trip.StopNo ?? ''),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              routeNo,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: routeNo.length < 3 ? 50 : 35,
                height: 1.0,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white70 : colorFromHex('#10295D'),
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
                    activeTrip.Destination ?? '',
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: isDarkMode ? Colors.white70 : colorFromHex('#024D7E'),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 15),
                  child: Text(
                    '${patternToDirection(activeTrip.Pattern ?? '')} at \n${activeTrip.nextStop ?? ''}',
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.0,
                      fontWeight: FontWeight.w400,
                      color: colorFromHex('1bab65'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 83,
            child: Text(
              '${activeTrip.ExpectedCountdown ?? 0} min',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize:
                    (activeTrip.ExpectedCountdown?.toString().length ?? 1) < 3
                        ? 24
                        : 20,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: isDarkMode ? Colors.white70 : colorFromHex('#10295D'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            onPageChanged: (index, _) => onCarouselChanged(index),
            height: 64.0,
            viewportFraction: 1.0,
          ),
          items: route.Trips.map((trip) {
            return Builder(builder: (_) => _buildSlide(trip));
          }).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: route.Trips.asMap().entries.map((entry) {
            final bool isActive = carouselIndex == entry.key;
            return Container(
              width: 6.0,
              height: 5.0,
              margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? (isDarkMode
                        ? const Color.fromRGBO(255, 255, 255, 0.3)
                        : const Color.fromRGBO(0, 0, 0, 0.3))
                    : (isDarkMode
                        ? const Color.fromRGBO(255, 255, 255, 0.15)
                        : const Color.fromRGBO(0, 0, 0, 0.15)),
              ),
            );
          }).toList(),
        ),
        Divider(color: Theme.of(context).primaryColor),
      ],
    );
  }
}
