import 'package:app_settings/app_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/util/TransitLiveTimer.dart';
import 'package:transitapp/util/TransitUtil.dart';
import 'package:transitapp/widgets/BusTile.dart';

class BusListSheet extends StatelessWidget {
  final List<BothDirectionRouteWithTrips> routes;
  final List<int> carouselIndices;
  final bool isDarkMode;
  final bool isLoading;
  final bool isLocationEnabled;
  final bool isViewingStop;
  final Duration timeSinceRefresh;
  final String statusText;
  final VoidCallback onRefresh;
  final void Function(int routeIndex, int carouselIndex) onCarouselChanged;
  final void Function(String routeNo, String pattern, String stopNo) onBusTap;

  const BusListSheet({
    super.key,
    required this.routes,
    required this.carouselIndices,
    required this.isDarkMode,
    required this.isLoading,
    required this.isLocationEnabled,
    required this.isViewingStop,
    required this.timeSinceRefresh,
    required this.statusText,
    required this.onRefresh,
    required this.onCarouselChanged,
    required this.onBusTap,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          color: Colors.deepOrangeAccent.withAlpha(0),
          child: Stack(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(0.0, 27.0, 0.0, 0.0),
                color: isDarkMode
                    ? colorFromHex('1b2336').withAlpha(252)
                    : Colors.white.withAlpha(252),
                child: Stack(
                  children: [
                    AnimatedOpacity(
                      opacity: routes.isNotEmpty ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 2),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 15, 0, 0),
                        controller: scrollController,
                        itemCount: routes.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            key: Key(routes[index].RouteNo),
                            contentPadding: EdgeInsets.zero,
                            title: BusTile(
                              route: routes[index],
                              carouselIndex: carouselIndices[index],
                              isDarkMode: isDarkMode,
                              onCarouselChanged: (ci) =>
                                  onCarouselChanged(index, ci),
                              onTap: (routeNo, pattern, stopNo) =>
                                  onBusTap(routeNo, pattern, stopNo),
                            ),
                          );
                        },
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedOpacity(
                            opacity: routes.isEmpty ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 20),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 19,
                                ),
                                text: statusText,
                              ),
                            ),
                          ),
                          Visibility(
                            visible: !isLocationEnabled,
                            child: Flexible(
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(35, 10, 30, 0),
                                child: RichText(
                                  text: TextSpan(
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () =>
                                          AppSettings.openAppSettings(
                                            type: AppSettingsType.location,
                                          ),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w300,
                                      fontSize: 16,
                                    ),
                                    text: !isViewingStop
                                        ? 'Please allow Transit to access your location to improve your experience'
                                        : '',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 70.0,
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: FittedBox(
                    child: FloatingActionButton(
                      heroTag: 'refresh',
                      onPressed: onRefresh,
                      backgroundColor: Colors.grey,
                      child: const Icon(
                        Icons.refresh,
                        size: 50,
                        color: Color.fromRGBO(255, 255, 255, 0.9),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0.0,
                child: TransitLiveTimer(isLoading, timeSinceRefresh),
              ),
            ],
          ),
        );
      },
    );
  }
}
