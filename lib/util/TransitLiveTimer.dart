import 'package:flutter/material.dart';

class TransitLiveTimer extends StatelessWidget {
  final bool isLoading;
  final Duration timeDifference;

  const TransitLiveTimer(this.isLoading, this.timeDifference, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42.0,
      height: 25.0,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.95),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(15.0)),
      ),
      child: Align(
        alignment: Alignment.center,
        child: RichText(
          text: TextSpan(
            children: [
              const WidgetSpan(child: Icon(Icons.rss_feed, size: 16, color: Colors.grey)),
              TextSpan(
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.normal,
                  fontSize: 13,
                  color: Colors.grey,
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
