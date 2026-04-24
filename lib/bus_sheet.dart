import 'package:app_settings/app_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'models/BothDirectionRouteWithTrips.dart';
import 'route_tile.dart';
import 'transit_util.dart';
import 'util/TransitLiveTimer.dart';

class BusSheet extends StatelessWidget {
  final List<BothDirectionRouteWithTrips> nextBuses;
  final List dotList;
  final bool darkModeOn;
  final String emptyText;
  final bool isLocationEnabled;
  final bool tappedIntoStop;
  final bool isLoading;
  final Duration timeDifference;
  final VoidCallback onRefresh;
  final VoidCallback onCenterLocation;
  final Future<void> Function(String routeNo, String pattern, String stopNo) onTripTap;
  final void Function(int routeIndex, int dotIndex) onDotChanged;

  const BusSheet({
    super.key,
    required this.nextBuses,
    required this.dotList,
    required this.darkModeOn,
    required this.emptyText,
    required this.isLocationEnabled,
    required this.tappedIntoStop,
    required this.isLoading,
    required this.timeDifference,
    required this.onRefresh,
    required this.onCenterLocation,
    required this.onTripTap,
    required this.onDotChanged,
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
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              margin: const EdgeInsets.fromLTRB(0.0, 50.0, 0.0, 0.0),
              color: darkModeOn
                  ? getColorFromHex('1b2336').withAlpha(252)
                  : Colors.white.withAlpha(252),
              child: Stack(children: [
                AnimatedOpacity(
                  opacity: nextBuses.isNotEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 2),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 15, 0, 0),
                    controller: scrollController,
                    itemCount: nextBuses.length,
                    itemBuilder: (context, index) => RouteTile(
                      route: nextBuses[index],
                      dotIndex: dotList[index] as int,
                      darkModeOn: darkModeOn,
                      onDotChanged: (dot) => onDotChanged(index, dot),
                      onTripTap: onTripTap,
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedOpacity(
                        opacity: nextBuses.isEmpty ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 20),
                        child: Align(
                          alignment: Alignment.center,
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.normal,
                                fontSize: 19,
                              ),
                              text: emptyText,
                            ),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: !isLocationEnabled,
                        child: Flexible(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(35, 10, 30, 0),
                            child: RichText(
                              text: TextSpan(
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => AppSettings.openAppSettings(
                                      type: AppSettingsType.location),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w300,
                                  fontStyle: FontStyle.normal,
                                  fontSize: 16,
                                ),
                                text: tappedIntoStop
                                    ? ''
                                    : 'Please allow Transit to access your location to improve your experience',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            Positioned(
              left: 7.0,
              top: -7.0,
              child: SizedBox(
                height: 50,
                width: 50,
                child: FittedBox(
                  child: FloatingActionButton(
                    heroTag: 'refreshBtn',
                    shape: const CircleBorder(),
                    onPressed: onRefresh,
                    backgroundColor: const Color.fromRGBO(255, 255, 255, 0.95),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black54,
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                            size: 24,
                            color: Color.fromRGBO(0, 0, 0, 1),
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 65.0,
              top: 17.0,
              child: TransitLiveTimer(isLoading, timeDifference),
            ),
            Positioned(
              right: 7.0,
              top: -7.0,
              child: SizedBox(
                height: 50,
                width: 50,
                child: FittedBox(
                  child: FloatingActionButton(
                    heroTag: 'centerLocation',
                    shape: const CircleBorder(),
                    onPressed: onCenterLocation,
                    backgroundColor: const Color.fromRGBO(255, 255, 255, 0.95),
                    child: const Icon(
                      Icons.my_location,
                      size: 24,
                      color: Color.fromRGBO(0, 0, 0, 1),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}
