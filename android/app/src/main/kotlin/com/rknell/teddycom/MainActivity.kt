package com.rknell.teddycom

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var savedAlarmVolume: Int = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.rknell.teddycom/alarm_audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "boostAlarmVolume" -> {
                    try {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        if (savedAlarmVolume < 0) {
                            savedAlarmVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
                        }
                        val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                        am.setStreamVolume(AudioManager.STREAM_ALARM, max, 0)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("BOOST_FAIL", e.message, null)
                    }
                }
                "restoreAlarmVolume" -> {
                    try {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        if (savedAlarmVolume >= 0) {
                            am.setStreamVolume(AudioManager.STREAM_ALARM, savedAlarmVolume, 0)
                            savedAlarmVolume = -1
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("RESTORE_FAIL", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
