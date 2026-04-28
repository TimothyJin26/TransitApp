import 'package:flutter/material.dart';

class TransitLiveTimer extends StatelessWidget {
  final bool isLoading;
  final Duration timeDifference;
  final bool isDark;

  const TransitLiveTimer(this.isLoading, this.timeDifference, {super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? const Color.fromRGBO(50, 52, 58, 1)
        : const Color.fromRGBO(255, 255, 255, 0.95);
    final contentColor = isDark
        ? const Color.fromRGBO(142, 142, 147, 1)
        : Colors.grey;

    return Container(
      width: 42.0,
      height: 25.0,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(15.0)),
      ),
      child: Align(
        alignment: Alignment.center,
        child: RichText(
          text: TextSpan(
            children: [
              WidgetSpan(child: Icon(Icons.rss_feed, size: 16, color: contentColor)),
              TextSpan(
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.normal,
                  fontSize: 13,
                  color: contentColor,
                ),
                text: '${30 - timeDifference.inSeconds}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
