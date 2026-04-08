import "dart:io";

import "package:dexcom_share_api/dexcom_share_api.dart";
import "package:test/test.dart";

import "test_env.dart";

void main() {
  final env = loadTestEnv(environment: Platform.environment);
  final username = env["DEXCOM_USERNAME"]?.trim();
  final password = env["DEXCOM_PASSWORD"]?.trim();
  final configuredServer = env["DEXCOM_SERVER"]?.trim();

  final hasCreds = (username != null && username.isNotEmpty) &&
      (password != null && password.isNotEmpty);

  Future<List<GlucoseEntry>> readWithServerFailover({
    required LatestGlucoseOptions options,
  }) async {
    final u = username;
    final p = password;
    if (u == null || u.isEmpty || p == null || p.isEmpty) {
      throw StateError("Missing DEXCOM_USERNAME/DEXCOM_PASSWORD for test run.");
    }

    final serversToTry = (configuredServer != null && configuredServer.isNotEmpty)
        ? <String>[configuredServer]
        : const <String>["us", "eu"];

    DexcomApiException? lastApiErr;
    Object? lastOtherErr;

    for (final server in serversToTry) {
      final client = DexcomClient(username: u, password: p, server: server);
      try {
        final readings = await client.getEstimatedGlucoseValues(options);
        return readings;
      } on DexcomApiException catch (err) {
        lastApiErr = err;
      } catch (err) {
        lastOtherErr = err;
      } finally {
        client.close();
      }
    }

    if (lastApiErr != null) throw lastApiErr;
    throw StateError("Dexcom request failed: $lastOtherErr");
  }

  group("DexcomClient integration", () {
    test("🚀 FEATURE: read current glucose entry", () async {
      if (!hasCreds) {
        return;
      }

      final readings = await readWithServerFailover(
        options: const LatestGlucoseOptions(minutes: 30, maxCount: 1),
      );

      expect(readings, isNotEmpty);
      expect(readings.length, 1);

      final entry = readings.single;
      expect(entry.mgdl, greaterThan(0));
      expect(entry.mmol, closeTo(entry.mgdl / 18.0, 0.02));
      expect(entry.trend, isA<Trend>());
      expect(DateTime.parse(entry.timestamp), isA<DateTime>());
    });

    test("🛡️ REGRESSION: read historical glucose batch", () async {
      if (!hasCreds) {
        return;
      }

      final readings = await readWithServerFailover(
        options: const LatestGlucoseOptions(minutes: 24 * 60, maxCount: 48),
      );

      expect(readings, isNotEmpty);
      expect(readings.length, lessThanOrEqualTo(48));

      for (final entry in readings) {
        expect(entry.mgdl, greaterThan(0));
        expect(entry.mmol, closeTo(entry.mgdl / 18.0, 0.02));
        expect(entry.trend, isA<Trend>());
        expect(DateTime.parse(entry.timestamp), isA<DateTime>());
      }
    });
  }, timeout: const Timeout(Duration(seconds: 30)));
}
