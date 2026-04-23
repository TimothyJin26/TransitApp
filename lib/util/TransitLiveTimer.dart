import 'package:flutter/material.dart';
import 'package:transitapp/util/TransitUtil.dart';

class TransitLiveTimer extends StatelessWidget {
  final bool isLoading;
  final Duration timeDifference;

  const TransitLiveTimer(this.isLoading, this.timeDifference, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 65.0,
      height: 25.0,
      decoration: BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
      ),
      child: Align(
        alignment: Alignment.center,
        child: RichText(
          text: TextSpan(
            children: [
              WidgetSpan(
                child: isLoading
                    ? SizedBox(
                        height: 15,
                        width: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          backgroundColor: colorFromHex('1bab65'),
                        ),
                      )
                    : const Icon(Icons.rss_feed, size: 16),
              ),
              if (!isLoading)
                TextSpan(
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                    fontSize: 13,
                  ),
                  text: '${30 - timeDifference.inSeconds} sec',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
