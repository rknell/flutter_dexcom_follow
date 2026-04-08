import "dart:convert";

import "package:http/http.dart" as http;

import "types.dart";
import "utilities.dart";

class DexcomClient {
  DexcomClient({
    required String username,
    required String password,
    required String server,
    http.Client? httpClient,
  })  : _username = username,
        _password = password,
        _server = normalizeServer(server),
        _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null {
    if (username.isEmpty) {
      throw ArgumentError("Must provide username");
    }
    if (password.isEmpty) {
      throw ArgumentError("Must provide password");
    }
    if (server.trim().isEmpty) {
      throw ArgumentError("Must provide server");
    }
  }

  final String _username;
  final String _password;
  final DexcomServer _server;
  final http.Client _http;
  final bool _ownsClient;

  static const _applicationIds = <DexcomServer, String>{
    DexcomServer.us: "d89443d2-327c-4a6f-89e5-496bbb0317db",
    DexcomServer.eu: "d89443d2-327c-4a6f-89e5-496bbb0317db",
  };

  String get _applicationId => _applicationIds[_server]!;

  void close() {
    if (_ownsClient) _http.close();
  }

  Uri _apiUrl(String resource) {
    final host = switch (_server) {
      DexcomServer.us => "share2.dexcom.com",
      DexcomServer.eu => "shareous1.dexcom.com",
    };

    return Uri.https(host, "/ShareWebServices/Services/$resource");
  }

  Future<Object?> _readBody(http.Response response) async {
    final contentType = response.headers["content-type"] ?? "";
    if (contentType.contains("application/json")) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    return response.body;
  }

  String _normalizeQuotedId(Object? value) {
    final str = (value is String) ? value : "$value";
    return str.replaceAll('"', "").trim();
  }

  Trend _normalizeTrend(Object raw) {
    // Dexcom used to rank trends from 1-7 (1 = max raise, 7 = max drop)
    // This recently changed to use human readable strings instead.
    if (raw is num) {
      final idx = raw.toInt();
      if (idx < 1 || idx > trendValues.length) {
        throw ArgumentError("Unexpected Dexcom trend index: $raw");
      }
      return trendFromNormalizedString(trendValues[idx - 1]);
    }

    return trendFromNormalizedString(raw.toString().toLowerCase());
  }

  /// Returns the Dexcom `account_id`.
  Future<String> getAccountId() async {
    try {
      final response = await _http.post(
        _apiUrl("General/AuthenticatePublisherAccount"),
        headers: const {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "applicationId": _applicationId,
          "accountName": _username,
          "password": _password,
        }),
      );

      final data = await _readBody(response);
      if (response.statusCode != 200) {
        throw DexcomApiException(
          "Dexcom server responded with status: ${response.statusCode}",
          statusCode: response.statusCode,
          data: data,
        );
      }

      return _normalizeQuotedId(data);
    } catch (err) {
      throw DexcomApiException("Request failed with error: $err");
    }
  }

  /// Returns the Dexcom `session_id` for a given account.
  Future<String> getSessionId() async {
    try {
      final accountId = await getAccountId();

      final response = await _http.post(
        _apiUrl("General/LoginPublisherAccountById"),
        headers: const {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "applicationId": _applicationId,
          "accountId": accountId,
          "password": _password,
        }),
      );

      final data = await _readBody(response);
      if (response.statusCode != 200) {
        throw DexcomApiException(
          "Dexcom server responded with status: ${response.statusCode}",
          statusCode: response.statusCode,
          data: data,
        );
      }

      return _normalizeQuotedId(data);
    } catch (err) {
      throw DexcomApiException("Request failed with error: $err");
    }
  }

  /// Returns the latest glucose levels between a given time (expressed as
  /// minutes) in the past and now.
  ///
  /// Defaults to the latest entry in the past 24 hours.
  Future<List<GlucoseEntry>> getEstimatedGlucoseValues([
    LatestGlucoseOptions options = const LatestGlucoseOptions(),
  ]) async {
    try {
      final sessionId = await getSessionId();

      final response = await _http.post(
        _apiUrl("Publisher/ReadPublisherLatestGlucoseValues"),
        headers: const {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "maxCount": options.maxCount,
          "minutes": options.minutes,
          "sessionId": sessionId,
        }),
      );

      final data = await _readBody(response);
      if (response.statusCode != 200) {
        throw DexcomApiException(
          "Dexcom server responded with status: ${response.statusCode}",
          statusCode: response.statusCode,
          data: data,
        );
      }

      if (data is! List) {
        throw DexcomApiException("Unexpected Dexcom response: $data", data: data);
      }

      return data.map((raw) {
        if (raw is! Map) {
          throw DexcomApiException("Unexpected Dexcom entry: $raw", data: raw);
        }
        final entry = DexcomEntry.fromJson(raw.cast<String, Object?>());
        final trend = _normalizeTrend(entry.trend);

        final millis = extractNumber(entry.wt);
        if (millis == null) {
          throw DexcomApiException("Unexpected Dexcom WT value: ${entry.wt}");
        }
        final timestamp = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
            .toIso8601String();

        return GlucoseEntry(
          mgdl: entry.value,
          mmol: mgdlToMmol(entry.value),
          trend: trend,
          timestamp: timestamp,
        );
      }).toList(growable: false);
    } catch (err) {
      throw DexcomApiException("Request failed with error: $err");
    }
  }
}
