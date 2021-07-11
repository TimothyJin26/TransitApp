import 'package:transitapp/models/Trip.dart';

class PopupInfo {
  PopupInfo(String stopNo, String routeNo, String pattern) {
    this.stopNo = stopNo;
    this.routeNo = routeNo;
    this.pattern = pattern;
  }

  String routeNo;
  String stopNo;
  String pattern;
}
