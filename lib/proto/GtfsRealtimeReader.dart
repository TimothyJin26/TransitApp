import 'dart:convert';
import 'dart:typed_data';

/// Lightweight GTFS Realtime protobuf decoder.
/// Only decodes the fields this app actually needs.

class GtfsTripUpdate {
  final String tripId;
  final String routeId;
  final int directionId;
  final List<GtfsStopTimeUpdate> stopTimeUpdates;

  const GtfsTripUpdate({
    required this.tripId,
    required this.routeId,
    required this.directionId,
    required this.stopTimeUpdates,
  });
}

class GtfsStopTimeUpdate {
  final String stopId;

  /// Unix epoch seconds for expected departure (falls back to arrival).
  final int? time;

  const GtfsStopTimeUpdate({required this.stopId, required this.time});
}

class GtfsVehiclePosition {
  final String vehicleId;
  final String tripId;
  final String routeId;
  final double latitude;
  final double longitude;
  final double? bearing;

  const GtfsVehiclePosition({
    required this.vehicleId,
    required this.tripId,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.bearing,
  });
}

class GtfsRealtimeReader {
  // ── Public entry points ────────────────────────────────────────────────────

  static List<GtfsTripUpdate> parseTripUpdates(Uint8List bytes) {
    final r = _R(bytes);
    final out = <GtfsTripUpdate>[];
    while (r.hasMore) {
      final tag = r.varint();
      if (tag >> 3 == 2 && tag & 7 == 2) {
        final tu = _tripUpdateFromEntity(r.bytes());
        if (tu != null) out.add(tu);
      } else {
        r.skip(tag & 7);
      }
    }
    return out;
  }

  static List<GtfsVehiclePosition> parseVehiclePositions(Uint8List bytes) {
    final r = _R(bytes);
    final out = <GtfsVehiclePosition>[];
    while (r.hasMore) {
      final tag = r.varint();
      if (tag >> 3 == 2 && tag & 7 == 2) {
        final vp = _vehiclePositionFromEntity(r.bytes());
        if (vp != null) out.add(vp);
      } else {
        r.skip(tag & 7);
      }
    }
    return out;
  }

  // ── Trip update parsing ────────────────────────────────────────────────────

  static GtfsTripUpdate? _tripUpdateFromEntity(Uint8List bytes) {
    final r = _R(bytes);
    Uint8List? tuBytes;
    while (r.hasMore) {
      final tag = r.varint();
      if (tag >> 3 == 3 && tag & 7 == 2) {
        tuBytes = r.bytes();
      } else {
        r.skip(tag & 7);
      }
    }
    return tuBytes != null ? _parseTripUpdate(tuBytes) : null;
  }

  static GtfsTripUpdate? _parseTripUpdate(Uint8List bytes) {
    final r = _R(bytes);
    String tripId = '', routeId = '';
    int dirId = 0;
    final stus = <GtfsStopTimeUpdate>[];
    while (r.hasMore) {
      final tag = r.varint();
      final field = tag >> 3;
      final wire = tag & 7;
      if (field == 1 && wire == 2) {
        final td = _parseTripDescriptor(r.bytes());
        tripId = td.tripId;
        routeId = td.routeId;
        dirId = td.dirId;
      } else if (field == 2 && wire == 2) {
        final stu = _parseStopTimeUpdate(r.bytes());
        if (stu != null) stus.add(stu);
      } else {
        r.skip(wire);
      }
    }
    if (tripId.isEmpty && routeId.isEmpty) return null;
    return GtfsTripUpdate(
        tripId: tripId,
        routeId: routeId,
        directionId: dirId,
        stopTimeUpdates: stus);
  }

  static ({String tripId, String routeId, int dirId}) _parseTripDescriptor(
      Uint8List bytes) {
    final r = _R(bytes);
    String tripId = '', routeId = '';
    int dirId = 0;
    while (r.hasMore) {
      final tag = r.varint();
      final field = tag >> 3;
      final wire = tag & 7;
      if (field == 1 && wire == 2) {
        tripId = r.string();
      } else if (field == 5 && wire == 2) {
        routeId = r.string();
      } else if (field == 6 && wire == 0) {
        dirId = r.varint();
      } else {
        r.skip(wire);
      }
    }
    return (tripId: tripId, routeId: routeId, dirId: dirId);
  }

  static GtfsStopTimeUpdate? _parseStopTimeUpdate(Uint8List bytes) {
    final r = _R(bytes);
    String stopId = '';
    int? departure, arrival;
    while (r.hasMore) {
      final tag = r.varint();
      final field = tag >> 3;
      final wire = tag & 7;
      if (field == 4 && wire == 2) {
        stopId = r.string();
      } else if (field == 2 && wire == 2) {
        arrival = _parseStopTimeEvent(r.bytes());
      } else if (field == 3 && wire == 2) {
        departure = _parseStopTimeEvent(r.bytes());
      } else {
        r.skip(wire);
      }
    }
    if (stopId.isEmpty) return null;
    return GtfsStopTimeUpdate(stopId: stopId, time: departure ?? arrival);
  }

  static int? _parseStopTimeEvent(Uint8List bytes) {
    final r = _R(bytes);
    int? time;
    while (r.hasMore) {
      final tag = r.varint();
      if (tag >> 3 == 2 && tag & 7 == 0) {
        time = r.varint();
      } else {
        r.skip(tag & 7);
      }
    }
    return time;
  }

  // ── Vehicle position parsing ───────────────────────────────────────────────

  static GtfsVehiclePosition? _vehiclePositionFromEntity(Uint8List bytes) {
    final r = _R(bytes);
    Uint8List? vpBytes;
    while (r.hasMore) {
      final tag = r.varint();
      if (tag >> 3 == 4 && tag & 7 == 2) {
        vpBytes = r.bytes();
      } else {
        r.skip(tag & 7);
      }
    }
    return vpBytes != null ? _parseVehiclePosition(vpBytes) : null;
  }

  static GtfsVehiclePosition? _parseVehiclePosition(Uint8List bytes) {
    final r = _R(bytes);
    String vehicleId = '', tripId = '', routeId = '';
    double lat = 0, lng = 0;
    double? bearing;
    while (r.hasMore) {
      final tag = r.varint();
      final field = tag >> 3;
      final wire = tag & 7;
      if (field == 1 && wire == 2) {
        final td = _parseTripDescriptor(r.bytes());
        tripId = td.tripId;
        routeId = td.routeId;
      } else if (field == 2 && wire == 2) {
        final pos = _parsePosition(r.bytes());
        lat = pos.$1;
        lng = pos.$2;
        bearing = pos.$3;
      } else if (field == 8 && wire == 2) {
        vehicleId = _parseVehicleId(r.bytes());
      } else {
        r.skip(wire);
      }
    }
    if (lat == 0 && lng == 0) return null;
    return GtfsVehiclePosition(
        vehicleId: vehicleId,
        tripId: tripId,
        routeId: routeId,
        latitude: lat,
        longitude: lng,
        bearing: bearing);
  }

  static (double, double, double?) _parsePosition(Uint8List bytes) {
    final r = _R(bytes);
    double lat = 0, lng = 0;
    double? bearing;
    while (r.hasMore) {
      final tag = r.varint();
      final field = tag >> 3;
      final wire = tag & 7;
      if (field == 1 && wire == 5) {
        lat = r.float32();
      } else if (field == 2 && wire == 5) {
        lng = r.float32();
      } else if (field == 3 && wire == 5) {
        bearing = r.float32();
      } else {
        r.skip(wire);
      }
    }
    return (lat, lng, bearing);
  }

  static String _parseVehicleId(Uint8List bytes) {
    final r = _R(bytes);
    String id = '', label = '';
    while (r.hasMore) {
      final tag = r.varint();
      final field = tag >> 3;
      final wire = tag & 7;
      if (field == 1 && wire == 2) {
        id = r.string();
      } else if (field == 2 && wire == 2) {
        label = r.string();
      } else {
        r.skip(wire);
      }
    }
    return id.isNotEmpty ? id : label;
  }
}

/// Minimal protobuf binary reader.
class _R {
  final Uint8List _d;
  int _p = 0;

  _R(this._d);

  bool get hasMore => _p < _d.length;

  int varint() {
    int r = 0, shift = 0;
    while (_p < _d.length) {
      final b = _d[_p++];
      r |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    return r;
  }

  String string() {
    final len = varint();
    final s = utf8.decode(_d.sublist(_p, _p + len));
    _p += len;
    return s;
  }

  Uint8List bytes() {
    final len = varint();
    final b = Uint8List.fromList(_d.sublist(_p, _p + len));
    _p += len;
    return b;
  }

  double float32() {
    final bd = ByteData.view(_d.buffer, _d.offsetInBytes + _p, 4);
    _p += 4;
    return bd.getFloat32(0, Endian.little);
  }

  void skip(int wireType) {
    switch (wireType) {
      case 0:
        varint();
      case 1:
        _p += 8;
      case 2:
        _p += varint();
      case 5:
        _p += 4;
    }
  }
}
