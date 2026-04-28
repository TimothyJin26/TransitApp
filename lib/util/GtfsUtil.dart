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

  /// Derive a direction pattern code from a stop's onStreet name.
  /// e.g. "Westbound Hastings St" → "W", falls back to "Outbound"/"Inbound".
  static String directionFromStop(String? onStreet, int directionId) {
    final s = onStreet?.trim().toLowerCase() ?? '';
    if (s.startsWith('westbound')) return 'W';
    if (s.startsWith('eastbound')) return 'E';
    if (s.startsWith('northbound')) return 'N';
    if (s.startsWith('southbound')) return 'S';
    return directionId == 0 ? 'Outbound' : 'Inbound';
  }

  /// Strip TransLink's leading route-number prefix from a trip headsign.
  /// e.g. "014 UBC Exchange" → "UBC Exchange"
  /// For express routes with "/to ": "R4 41st Ave/to Downtown" → "Downtown"
  static String stripHeadsignPrefix(String headsign) {
    final toIdx = headsign.toLowerCase().indexOf('/to ');
    if (toIdx != -1) return headsign.substring(toIdx + 4).trim();
    return headsign.replaceFirst(RegExp(r'^\w+\s+'), '');
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
    return '${atStreet.trim()} at $streetName';
  }
}
