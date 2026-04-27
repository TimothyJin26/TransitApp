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
  final void Function(String routeNo, String pattern, String stopNo) onTap;

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
      onTap: () => onTap(route.RouteNo, trip.Pattern ?? '', trip.StopNo ?? ''),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              width: 65,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: () {
                  final countdown = activeTrip.ExpectedCountdown ?? 0;
                  final timeColor = isDarkMode ? Colors.white70 : colorFromHex('#10295D');
                  if (countdown >= 60) {
                    final parts = (activeTrip.ExpectedLeaveTime ?? '').split(' ');
                    final timeStr = parts.isNotEmpty ? parts[0] : '';
                    final period = parts.length > 1 ? parts[1] : '';
                    return [
                      Text(
                        timeStr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          color: timeColor,
                        ),
                      ),
                      Text(
                        period,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: timeColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ];
                  }
                  return [
                    Text(
                      '$countdown',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: countdown.toString().length < 3 ? 32 : 26,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: timeColor,
                      ),
                    ),
                    Text(
                      'minutes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        color: timeColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ];
                }(),
              ),
            ),
          ],
        ),
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
