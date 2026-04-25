import 'dart:ui';

class SunsetHelper {
  static bool isDark() {
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }
}
