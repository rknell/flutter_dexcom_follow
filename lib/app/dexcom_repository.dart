import 'dart:async';

import 'package:dexcom_share_api/dexcom_share_api.dart';

class GlucoseSnapshot {
  final GlucoseEntry entry;
  final DateTime fetchedAt;

  const GlucoseSnapshot({required this.entry, required this.fetchedAt});
}

abstract class DexcomRepository {
  Stream<GlucoseSnapshot> watchLatest();
  Future<GlucoseSnapshot> refreshOnce();
  Future<List<GlucoseEntry>> fetchHistory({
    int minutes = 1440,
    int maxCount = 288,
  });
  Future<void> dispose();
}

class DexcomShareRepository implements DexcomRepository {
  DexcomShareRepository({
    required String username,
    required String password,
    required String server,
    Duration dexcomCadence = const Duration(minutes: 5),
    Duration probeInterval = const Duration(seconds: 30),
  }) : _client = DexcomClient(
         username: username,
         password: password,
         server: server,
       ),
       _dexcomCadence = dexcomCadence,
       _probeInterval = probeInterval;

  final DexcomClient _client;
  final Duration _dexcomCadence;
  final Duration _probeInterval;

  final _controller = StreamController<GlucoseSnapshot>.broadcast();
  Timer? _timer;
  bool _isRefreshing = false;
  String? _lastEmittedTimestamp;

  @override
  Stream<GlucoseSnapshot> watchLatest() {
    unawaited(_refreshAndEmit());
    return _controller.stream;
  }

  @override
  Future<GlucoseSnapshot> refreshOnce() async {
    final list = await _client.getEstimatedGlucoseValues(
      const LatestGlucoseOptions(maxCount: 1, minutes: 1440),
    );
    if (list.isEmpty) {
      throw DexcomApiException('Dexcom returned no glucose entries');
    }
    return GlucoseSnapshot(entry: list.first, fetchedAt: DateTime.now());
  }

  @override
  Future<List<GlucoseEntry>> fetchHistory({
    int minutes = 1440,
    int maxCount = 288,
  }) async {
    final list = await _client.getEstimatedGlucoseValues(
      LatestGlucoseOptions(maxCount: maxCount, minutes: minutes),
    );
    return list;
  }

  Future<void> _refreshAndEmit() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final snapshot = await refreshOnce();
      if (!_controller.isClosed) _controller.add(snapshot);
      _scheduleNextProbe(snapshot);
    } catch (e, st) {
      if (!_controller.isClosed) _controller.addError(e, st);
      _scheduleRetryProbe();
    } finally {
      _isRefreshing = false;
    }
  }

  void _scheduleRetryProbe() {
    _timer?.cancel();
    if (_controller.isClosed) return;
    _timer = Timer(_probeInterval, () => unawaited(_refreshAndEmit()));
  }

  void _scheduleNextProbe(GlucoseSnapshot snapshot) {
    _timer?.cancel();
    if (_controller.isClosed) return;

    final readingTime = DateTime.tryParse(snapshot.entry.timestamp)?.toLocal();
    final now = DateTime.now();
    final isNewReading = snapshot.entry.timestamp != _lastEmittedTimestamp;
    _lastEmittedTimestamp = snapshot.entry.timestamp;

    final Duration delay;
    if (isNewReading && readingTime != null) {
      final nextUsefulProbe = readingTime.add(_dexcomCadence);
      delay = nextUsefulProbe.isAfter(now)
          ? nextUsefulProbe.difference(now)
          : _probeInterval;
    } else {
      delay = _probeInterval;
    }

    _timer = Timer(delay, () => unawaited(_refreshAndEmit()));
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _client.close();
    await _controller.close();
  }
}
