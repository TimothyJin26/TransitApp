import 'dart:math';

import 'package:flutter/material.dart';
import 'package:transitapp/home.dart';

import 'fetchers/NextBusesForRouteAtStop.dart';
import 'models/Trip.dart';

class WaitTimesPopup extends StatefulWidget {
  WaitTimesPopup(String routeNo, String pattern, String stopNo) {
    this.routeNo = routeNo;
    this.pattern = pattern;
    this.stopNo = stopNo;
  }

  String routeNo;
  String pattern;
  String stopNo;

  @override
  WaitTimesPopupState createState() =>
      new WaitTimesPopupState(routeNo, pattern, stopNo);
}

class WaitTimesPopupState extends State<WaitTimesPopup> {
  WaitTimesPopupState(String routeNo, String pattern, String stopNo) {
    this.routeNo = routeNo;
    this.pattern = pattern;
    this.stopNo = stopNo;
  }

  String routeNo;
  String pattern;
  String stopNo;
  List<Trip> trips = [];

  String timeFormatter(String input) {
    String toRet = "";
    toRet = input.split(" ")[0];
    if (toRet.contains("am")) {
      toRet = toRet.substring(0, toRet.length - 2) + " AM";
    } else {
      toRet = toRet.substring(0, toRet.length - 2) + " PM";
    }
    return toRet;
  }

  @override
  void initState() {
    // This might take a while on the first load
    final NextBusesForRouteAtStop busFetcher = new NextBusesForRouteAtStop();
    final Future<List<Trip>> futureBuses =
        busFetcher.busAtSingleStopFetcher(stopNo, routeNo);
    futureBuses.then((value) {
      setState(() {
        trips = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new Container(
        padding: const EdgeInsets.only(top: 36.0),
        color: getColorFromHex('#024D7E'),
        child: Column(
          children: [
            Row(children: [
              FlatButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Row(children: [
                  Icon(Icons.arrow_back_ios, color: Colors.white70),
                  Text("Back", style: TextStyle(color: Colors.white70)),
                ]),
              )
            ]),
            Container(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                    text: routeNo,
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 100,
                    )),
              ),
            ),
            Container(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                    text: pattern,
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w800,
                      fontSize: 25,
                    )),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.transparent,
                margin: const EdgeInsets.only(
                    left: 12.0, right: 12.0, top: 24.0, bottom: 24.0),
                child: new Container(
                  decoration: new BoxDecoration(
                      color: getColorFromHex("#EEEEEE"),
                      borderRadius: new BorderRadius.only(
                        topLeft: const Radius.circular(24.0),
                        topRight: const Radius.circular(24.0),
                        bottomLeft: const Radius.circular(24.0),
                        bottomRight: const Radius.circular(24.0),
                      )),
                  child: Scrollbar(
                    child: ListView.builder(
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true,
                      itemCount: trips.length,
                      padding: const EdgeInsets.fromLTRB(8.0, 16.0, 8.0, 16.0),
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Row(
                            children: <Widget>[
                              Container(
                                width: 130,
                                child: RichText(
                                  textAlign: TextAlign.left,
                                  text: TextSpan(
                                      text: timeFormatter(
                                          trips[index].ExpectedLeaveTime),
                                      style: TextStyle(
                                        color: getColorFromHex('#0d2036'),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 20,
                                      )),
                                ),
                              ),
                              Container(
                                child: RichText(
                                  overflow: TextOverflow.fade,
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                      text: "TO " + trips[index].Destination,
                                      style: TextStyle(
                                        color: getColorFromHex('#0d2036'),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 18,
                                      )
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
