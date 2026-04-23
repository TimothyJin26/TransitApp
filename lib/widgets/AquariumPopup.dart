import 'package:flutter/material.dart';
import 'package:transitapp/util/TransitUtil.dart';
import 'package:url_launcher/url_launcher.dart';

void showAquariumPopup(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _AquariumContent(),
  );
}

class _AquariumContent extends StatelessWidget {
  const _AquariumContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Image.asset('images/fishcopy.png'),
            ),
          ),
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.fromLTRB(10, 15, 5, 15),
            child: const Text(
              'Due to the COVID-19 Pandemic, the Vancouver Aquarium paused all public programming. '
              'During this time, essential donations would be put towards the critical care of over 70000 animals. '
              '100% of ad revenue from this app goes towards the Vancouver Aquarium',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.3,
                fontWeight: FontWeight.w300,
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
          ),
          Center(
            child: Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorFromHex('256BD1'),
                    minimumSize: const Size(150, 55),
                  ),
                  onPressed: () =>
                      launchUrl(Uri.parse('https://www.vanaqua.org/transformation')),
                  child: const Text(
                    'Learn More',
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorFromHex('256BD1'),
                    minimumSize: const Size(150, 55),
                  ),
                  onPressed: () => launchUrl(
                      Uri.parse('https://www.vanaqua.org/support/ways-to-support')),
                  child: const Text(
                    'Donate',
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
