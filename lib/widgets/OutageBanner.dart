import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OutageBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const OutageBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Card(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const ListTile(
              title: Text('Bus Locations Temporarily Unavailable'),
              subtitle: Text(
                'Due to the ongoing Translink IT outage, only next stop times are available.',
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(
                    'https://www.translink.ca/news/2020/december/statement%20from%20translink%20ceo%20kevin%20desmond',
                  )),
                  child: const Text('Learn More'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
