import 'dart:async';

import 'package:flutter/material.dart';

class TransitLiveTimer extends StatefulWidget {
  final bool isLoading;
  final Duration timeDifference;
  const TransitLiveTimer(this.isLoading, this.timeDifference);

  @override
  _TransitLiveTimer createState() => _TransitLiveTimer();
}

class _TransitLiveTimer extends State<TransitLiveTimer> {

  @override
  Widget build(BuildContext context) {

   return Container(
      width: 65.0,
      height: 25.0,
      decoration: new BoxDecoration(color: Colors.grey, shape: BoxShape.rectangle, borderRadius: BorderRadius.all(Radius.circular(8.0))),
      child: Align(
          alignment: Alignment.center,
          child: RichText(
              text: TextSpan(children: [
                WidgetSpan(
                    child: widget.isLoading
                        ? SizedBox(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        backgroundColor: Colors.orange,
                      ),
                      height: 15,
                      width: 15,
                    )
                        : Icon(
                      Icons.rss_feed,
                      size: 16,
                    )),
                !widget.isLoading
                    ? TextSpan(
                    style: TextStyle(fontWeight: FontWeight.w400, fontStyle: FontStyle.normal, fontSize: 13),
                    text: ((30 - widget.timeDifference.inSeconds).toString()) + " sec")
                    : TextSpan(text: ""),
              ]))),
    );
  }
}