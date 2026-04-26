import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native channel: Android temporarily raises [STREAM_ALARM] volume (see MainActivity).
const _kAlarmAudioChannel = MethodChannel(
  'com.rknell.teddycom/alarm_audio',
);

class AlarmAudioPlayer {
  AlarmAudioPlayer({this.sampleRate = 44100, this.numChannels = 1});

  final int sampleRate;
  final int numChannels;

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _audioContextApplied = false;

  Future<void> open() async {}
  Future<void> close() async => stop();

  Future<void> playAlarm({
    Duration duration = const Duration(seconds: 6),
  }) async {
    if (_isPlaying) return;
    await _startPlayback(
      pcmBuilder: () =>
          _buildAlarmPcm16(duration: duration, sampleRate: sampleRate),
      duration: duration,
    );
  }

  /// Interrupts a normal alarm if needed. Used for non-disableable critical low BG.
  Future<void> playPanicAlarm({
    Duration duration = const Duration(seconds: 8),
  }) async {
    await stop();
    await _startPlayback(
      pcmBuilder: () =>
          _buildPanicAlarmPcm16(duration: duration, sampleRate: sampleRate),
      duration: duration,
    );
  }

  Future<void> playPredictedLowAlarm({
    Duration duration = const Duration(seconds: 6),
  }) async {
    await _startPlayback(
      pcmBuilder: () => _buildPredictedLowAlarmPcm16(
        duration: duration,
        sampleRate: sampleRate,
      ),
      duration: duration,
    );
  }

  Future<void> _startPlayback({
    required Int16List Function() pcmBuilder,
    required Duration duration,
  }) async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      await _ensureAlarmAudioContextOnce();
      await _player.setVolume(1.0);
      await _boostAndroidAlarmVolume();

      final pcm = pcmBuilder();
      final wav = _pcm16ToWavBytes(
        pcm,
        sampleRate: sampleRate,
        numChannels: numChannels,
      );

      await _player.play(BytesSource(wav));
      unawaited(Future<void>.delayed(duration).then((_) => stop()));
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    await _player.stop();
    await _restoreAndroidAlarmVolume();
  }

  Future<void> _ensureAlarmAudioContextOnce() async {
    if (_audioContextApplied || kIsWeb) return;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        await _player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.alarm,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.gainTransient,
            ),
          ),
        );
        _audioContextApplied = true;
      case TargetPlatform.iOS:
        await _player.setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
          ),
        );
        _audioContextApplied = true;
      default:
        _audioContextApplied = true;
    }
  }

  Future<void> _boostAndroidAlarmVolume() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _kAlarmAudioChannel.invokeMethod<void>('boostAlarmVolume');
    } catch (_) {
      // Missing permission, OEM restrictions, or emulator: still play at current alarm volume.
    }
  }

  Future<void> _restoreAndroidAlarmVolume() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _kAlarmAudioChannel.invokeMethod<void>('restoreAlarmVolume');
    } catch (_) {}
  }
}

Int16List _buildAlarmPcm16({
  required Duration duration,
  required int sampleRate,
}) {
  final totalFrames = (duration.inMilliseconds * sampleRate / 1000).round();
  final out = Int16List(totalFrames);

  // Alarm pattern: 2 chirps + short gap, repeating.
  final chirpMs = 120;
  final gapMs = 60;
  final blockMs = chirpMs + chirpMs + gapMs;
  final totalBlocks = max(1, (duration.inMilliseconds / blockMs).ceil());

  var writeFrame = 0;
  for (var b = 0; b < totalBlocks && writeFrame < totalFrames; b++) {
    writeFrame = _mixChirp(
      out,
      startFrame: writeFrame,
      ms: chirpMs,
      startHz: 880,
      endHz: 1320,
      amplitude: 0.65,
      sampleRate: sampleRate,
    );
    writeFrame = _mixChirp(
      out,
      startFrame: writeFrame,
      ms: chirpMs,
      startHz: 660,
      endHz: 1100,
      amplitude: 0.60,
      sampleRate: sampleRate,
    );
    writeFrame += (sampleRate * gapMs / 1000).round();
  }

  return out;
}

Int16List _buildPanicAlarmPcm16({
  required Duration duration,
  required int sampleRate,
}) {
  final totalFrames = (duration.inMilliseconds * sampleRate / 1000).round();
  final out = Int16List(totalFrames);

  // Harsh, fast siren-like pattern (critical hypoglycaemia).
  final burstMs = 42;
  final gapMs = 18;
  final blockMs = burstMs + gapMs + burstMs + gapMs + burstMs + gapMs;
  final totalBlocks = max(1, (duration.inMilliseconds / blockMs).ceil());

  var writeFrame = 0;
  for (var b = 0; b < totalBlocks && writeFrame < totalFrames; b++) {
    writeFrame = _mixChirp(
      out,
      startFrame: writeFrame,
      ms: burstMs,
      startHz: 1550,
      endHz: 2200,
      amplitude: 0.88,
      sampleRate: sampleRate,
    );
    writeFrame += (sampleRate * gapMs / 1000).round();
    writeFrame = _mixChirp(
      out,
      startFrame: writeFrame,
      ms: burstMs,
      startHz: 420,
      endHz: 280,
      amplitude: 0.82,
      sampleRate: sampleRate,
    );
    writeFrame += (sampleRate * gapMs / 1000).round();
    writeFrame = _mixChirp(
      out,
      startFrame: writeFrame,
      ms: burstMs,
      startHz: 1900,
      endHz: 900,
      amplitude: 0.9,
      sampleRate: sampleRate,
    );
    writeFrame += (sampleRate * gapMs / 1000).round();
  }

  return out;
}

Int16List _buildPredictedLowAlarmPcm16({
  required Duration duration,
  required int sampleRate,
}) {
  final totalFrames = (duration.inMilliseconds * sampleRate / 1000).round();
  final out = Int16List(totalFrames);

  // Predicted-low pattern: three short beeps, then a pause.
  final beepMs = 90;
  final gapMs = 80;
  final pauseMs = 720;
  final blockMs = beepMs + gapMs + beepMs + gapMs + beepMs + pauseMs;
  final totalBlocks = max(1, (duration.inMilliseconds / blockMs).ceil());

  var writeFrame = 0;
  for (var b = 0; b < totalBlocks && writeFrame < totalFrames; b++) {
    for (var i = 0; i < 3 && writeFrame < totalFrames; i++) {
      writeFrame = _mixChirp(
        out,
        startFrame: writeFrame,
        ms: beepMs,
        startHz: 1040,
        endHz: 1040,
        amplitude: 0.58,
        sampleRate: sampleRate,
      );
      writeFrame += (sampleRate * (i == 2 ? pauseMs : gapMs) / 1000).round();
    }
  }

  return out;
}

int _mixChirp(
  Int16List target, {
  required int startFrame,
  required int ms,
  required double startHz,
  required double endHz,
  required double amplitude,
  required int sampleRate,
}) {
  final frames = (sampleRate * ms / 1000).round();
  final endFrame = min(target.length, startFrame + frames);
  final twoPi = 2 * pi;
  var phase = 0.0;

  for (var i = startFrame; i < endFrame; i++) {
    final denom = max(1, (endFrame - startFrame) - 1).toDouble();
    final t = (i - startFrame) / denom;
    final hz = startHz + (endHz - startHz) * t;
    phase += twoPi * hz / sampleRate;
    final env = _raisedCosineEnvelope(t);
    final sample = sin(phase) * amplitude * env;
    target[i] = (sample * 32767).clamp(-32768, 32767).toInt();
  }

  return endFrame.toInt();
}

double _raisedCosineEnvelope(double t) {
  // 0..1 -> 0..1 smooth, with stronger damping near edges
  // Big-O: O(1)
  final a = 0.06;
  if (t < a) return 0.5 * (1 - cos(pi * (t / a)));
  if (t > (1 - a)) {
    final x = (1 - t) / a;
    return 0.5 * (1 - cos(pi * x));
  }
  return 1.0;
}

Uint8List _pcm16ToWavBytes(
  Int16List pcm, {
  required int sampleRate,
  required int numChannels,
}) {
  // PCM16 WAV header (little-endian). Big-O: O(n) to copy samples.
  final bytesPerSample = 2;
  final byteRate = sampleRate * numChannels * bytesPerSample;
  final blockAlign = numChannels * bytesPerSample;
  final dataSize = pcm.length * bytesPerSample;
  final riffSize = 36 + dataSize;

  final out = BytesBuilder(copy: false);
  out.add(_ascii('RIFF'));
  out.add(_u32le(riffSize));
  out.add(_ascii('WAVE'));
  out.add(_ascii('fmt '));
  out.add(_u32le(16)); // PCM fmt chunk size
  out.add(_u16le(1)); // PCM
  out.add(_u16le(numChannels));
  out.add(_u32le(sampleRate));
  out.add(_u32le(byteRate));
  out.add(_u16le(blockAlign));
  out.add(_u16le(16)); // bits per sample
  out.add(_ascii('data'));
  out.add(_u32le(dataSize));

  // PCM payload
  out.add(pcm.buffer.asUint8List(pcm.offsetInBytes, dataSize));
  return out.toBytes();
}

Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);
Uint8List _u16le(int v) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);
Uint8List _u32le(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);
