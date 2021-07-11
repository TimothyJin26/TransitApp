import 'dart:ui';

import 'package:daylight/daylight.dart';
import 'package:flutter/scheduler.dart';

class SunsetHelper {
  static bool isDark() {
    final vancouver = DaylightLocation(49.3002649, -123.1311801);
    final berlinCalculator = DaylightCalculator(vancouver);
    final curTime = DateTime.now();
    final dailyResults = berlinCalculator.calculateForDay(curTime, Zenith.astronomical);
    return SchedulerBinding.instance.window.platformBrightness == Brightness.dark || curTime.isAfter(dailyResults.sunset);
  }
}
