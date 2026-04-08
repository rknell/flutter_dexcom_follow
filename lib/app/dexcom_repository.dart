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
    Duration pollInterval = const Duration(minutes: 5),
  })  : _client = DexcomClient(
          username: username,
          password: password,
          server: server,
        ),
        _pollInterval = pollInterval;

  final DexcomClient _client;
  final Duration _pollInterval;

  final _controller = StreamController<GlucoseSnapshot>.broadcast();
  Timer? _timer;
  bool _isRefreshing = false;

  @override
  Stream<GlucoseSnapshot> watchLatest() {
    _timer ??= Timer.periodic(_pollInterval, (_) {
      unawaited(_refreshAndEmit());
    });
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
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _client.close();
    await _controller.close();
  }
}

