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
          child: Stack(children: [
            Container(
              margin: const EdgeInsets.fromLTRB(0.0, 27.0, 0.0, 0.0),
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
              right: 70.0,
              child: SizedBox(
                height: 24,
                width: 24,
                child: FittedBox(
                  child: FloatingActionButton(
                    heroTag: 'pizzahut',
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
              child: TransitLiveTimer(isLoading, timeDifference),
            ),
          ]),
        );
      },
    );
  }
}
