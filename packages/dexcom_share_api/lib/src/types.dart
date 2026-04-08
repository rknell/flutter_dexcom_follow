// In Dexcom terms, "eu" means everywhere not in the US (OUS / international),
// which includes countries like Australia.
enum DexcomServer { eu, us }

/// Convenience aliases accepted by the client constructor.
///
/// Mirrors the TypeScript client, which treats anything not explicitly "us"
/// as "eu".
DexcomServer normalizeServer(String server) {
  final s = server.trim().toLowerCase();
  if (s == "us") return DexcomServer.us;
  return DexcomServer.eu;
}

const trendValues = <String>[
  "doubleup",
  "singleup",
  "fortyfiveup",
  "flat",
  "fortyfivedown",
  "singledown",
  "doubledown",
];

/// Dart representation of the normalized trend values returned by this client.
enum Trend {
  doubleup,
  singleup,
  fortyfiveup,
  flat,
  fortyfivedown,
  singledown,
  doubledown,
}

Trend trendFromNormalizedString(String value) {
  final v = value.toLowerCase();
  return switch (v) {
    "doubleup" => Trend.doubleup,
    "singleup" => Trend.singleup,
    "fortyfiveup" => Trend.fortyfiveup,
    "flat" => Trend.flat,
    "fortyfivedown" => Trend.fortyfivedown,
    "singledown" => Trend.singledown,
    "doubledown" => Trend.doubledown,
    _ => throw ArgumentError("Unexpected Dexcom trend value: $value"),
  };
}

String trendToNormalizedString(Trend trend) {
  return switch (trend) {
    Trend.doubleup => "doubleup",
    Trend.singleup => "singleup",
    Trend.fortyfiveup => "fortyfiveup",
    Trend.flat => "flat",
    Trend.fortyfivedown => "fortyfivedown",
    Trend.singledown => "singledown",
    Trend.doubledown => "doubledown",
  };
}

class LatestGlucoseOptions {
  final int minutes;
  final int maxCount;

  const LatestGlucoseOptions({this.minutes = 1440, this.maxCount = 1});
}

/// Raw Dexcom response entry (best-effort typed).
class DexcomEntry {
  final String wt;
  final String st;
  final String dt;
  final int value; // mg/dL
  final Object trend; // string or number

  DexcomEntry({
    required this.wt,
    required this.st,
    required this.dt,
    required this.value,
    required this.trend,
  });

  factory DexcomEntry.fromJson(Map<String, Object?> json) {
    final wt = json["WT"];
    final st = json["ST"];
    final dt = json["DT"];
    final value = json["Value"];
    final trend = json["Trend"];

    if (wt is! String || st is! String || dt is! String) {
      throw FormatException("Unexpected Dexcom entry time fields: $json");
    }
    if (value is! num) {
      throw FormatException("Unexpected Dexcom entry Value: $json");
    }
    if (trend == null) {
      throw FormatException("Unexpected Dexcom entry Trend: $json");
    }

    return DexcomEntry(
      wt: wt,
      st: st,
      dt: dt,
      value: value.toInt(),
      trend: trend,
    );
  }
}

class GlucoseEntry {
  final int mgdl;
  final double mmol;
  final Trend trend;
  final String timestamp; // ISO-8601

  GlucoseEntry({
    required this.mgdl,
    required this.mmol,
    required this.trend,
    required this.timestamp,
  });
}

class DexcomApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? data;

  DexcomApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}
