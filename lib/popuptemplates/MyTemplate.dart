import 'package:flutter/material.dart';
import 'package:flutter_beautiful_popup/main.dart';
import 'package:transitapp/fetchers/NextBusesForRouteAtStop.dart';
import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Trip.dart';

import '../home.dart';

class MyTemplate extends BeautifulPopupTemplate {
  final BeautifulPopup options;
  MyTemplate(this.options, this.routeNo, this.pattern, this.stopNo, this.trips) : super(options);

  @override
  final illustrationKey = 'images/mytemplate.png';
  @override
  Color get primaryColor => options.primaryColor ?? Color(0xff000000); // The default primary color of the template is Colors.black.
  @override
  final maxWidth = 400; // In most situations, the value is the illustration size.
  @override
  final maxHeight = 600;
  @override
  final bodyMargin = 10;


  final String routeNo;
  final String pattern;
  final String stopNo;
  List<Trip> trips;


  String timeFormatter (String input){
    String toRet = "";
    toRet = input.split(" ")[0];
    if(toRet.contains("am")){
      toRet = toRet.substring(0,toRet.length-2)+" AM";
    } else{
      toRet = toRet.substring(0,toRet.length-2)+" PM";
    }
    return toRet;
  }
  // You need to adjust the layout to fit into your illustration.
  @override
  get layout {
    print(trips);
    return [
      Positioned(
        child: Container(
          decoration: new BoxDecoration(
            borderRadius: new BorderRadius.circular(16.0),
            color: getColorFromHex('#0d2036'),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: percentH(6),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: routeNo,
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 100,
            )

          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: percentH(27),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
              text: pattern,
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w800,
                fontSize: 25,
              )

          ),
        ),
      ),
      Positioned(
        top: percentH(35),
        bottom: percentH(9.4),
        left: percentW(2),
        right: percentW(2),
        child: ListView.builder(
          itemCount: trips.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Row(
                children: <Widget>[
                  Container(
                    width: 120,
                    child: RichText(
                      textAlign: TextAlign.left,
                      text: TextSpan(
                          text: timeFormatter(trips[index].ExpectedLeaveTime),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 25,
                          )

                      ),
                    ),

                  ),
                  Expanded(
                  child: Container(
                    child: RichText(
                      overflow: TextOverflow.fade,
                      textAlign: TextAlign.center,
                      text: TextSpan(
                          text: "TO "+trips[index].Destination,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 20,
                          )

                      ),
                    ),

                  ),
                  ),],
              ),
            );
          },
        ),
      ),
      Positioned(
        bottom: percentW(1),
        left: percentW(5),
        right: percentW(5),
        child: actions ?? Container(),
      ),

    ];
  }
}