/// Shared utilities for GTFS-based fetchers.
class GtfsUtil {
  /// Format a Unix epoch seconds value as "h:mm AM/PM".
  static String formatTime(int unixSec) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unixSec * 1000);
    final h =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  /// Build the nextStop display string from a stop's street fields.
  static String nextStopLabel(
      {required String? name,
      required String? onStreet,
      required String? atStreet}) {
    if (atStreet == null ||
        atStreet.isEmpty ||
        onStreet == null ||
        onStreet.isEmpty) {
      return name ?? '';
    }
    final on = onStreet.trim();
    // Strip leading direction word (e.g. "Westbound ") so we show
    // just the street name, matching the old RTTI format.
    final spaceIdx = on.indexOf(' ');
    final streetName =
        spaceIdx >= 0 ? on.substring(spaceIdx + 1) : on;
    return '${atStreet.trim()} and \n$streetName';
  }
}
