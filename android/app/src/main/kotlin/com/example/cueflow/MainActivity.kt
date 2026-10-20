package com.example.cueflow

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "cueflow/audiotrack"
    private var audioTrack: AudioTrack? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val sampleRate = call.argument<Int>("sampleRate") ?: 48000
                        val channels = call.argument<Int>("channels") ?: 1
                        start(sampleRate, channels)
                        result.success(true)
                    }
                    "write" -> {
                        val data = call.argument<ByteArray>("data")
                        if (data != null) write(data)
                        result.success(true)
                    }
                    "stop" -> {
                        stop()
                        result.success(true)
                    }
                    "setVolume" -> {
                        val volume = call.argument<Double>("volume") ?: 1.0
                        audioTrack?.setVolume(volume.toFloat())
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun start(sampleRate: Int, channels: Int) {
        stop()
        val channelMask =
            if (channels == 1) AudioFormat.CHANNEL_OUT_MONO
            else AudioFormat.CHANNEL_OUT_STEREO

        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            channelMask,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = maxOf(minBuf, sampleRate / 5 * channels * 2)

        val builder = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelMask)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
        }

        audioTrack = builder.build().also {
            it.play()
        }
    }

    private fun write(data: ByteArray) {
        val track = audioTrack ?: return
        try {
            track.write(data, 0, data.size)
        } catch (_: Exception) {
        }
    }

    private fun stop() {
        audioTrack?.let {
            try {
                it.pause()
                it.flush()
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        audioTrack = null
    }

    override fun onDestroy() {
        stop()
        super.onDestroy()
    }
}
