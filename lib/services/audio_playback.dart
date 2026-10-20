import 'dart:async';
import 'package:flutter/services.dart';
import 'opus_codec.dart';

class AudioPlayback {
  static const MethodChannel _channel = MethodChannel('cueflow/audiotrack');

  final OpusCodec _codec = OpusCodec();
  final List<Uint8List> _buffer = [];
  Timer? _timer;
  bool _running = false;

  int _minFrames;
  int _maxFrames;

  double _mdVolume = 1.0;
  double _secondVolume = 1.0;
  bool _mdMuted = false;
  bool _secondMuted = false;

  AudioPlayback({int jitterMs = 80})
      : _minFrames = (jitterMs / OpusCodec.frameMs).round(),
        _maxFrames = (jitterMs / OpusCodec.frameMs).round() + 4;

  void setVolumes({
    required double md,
    required double second,
    required bool mdMuted,
    required bool secondMuted,
  }) {
    _mdVolume = md;
    _secondVolume = second;
    _mdMuted = mdMuted;
    _secondMuted = secondMuted;
  }

  void setJitter(int ms) {
    _minFrames = (ms / OpusCodec.frameMs).round().clamp(1, 20);
    _maxFrames = _minFrames + 4;
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    try {
      await _channel.invokeMethod('start', {
        'sampleRate': OpusCodec.sampleRate,
        'channels': OpusCodec.channels,
      });
    } catch (_) {}
    _timer = Timer.periodic(
      const Duration(milliseconds: OpusCodec.frameMs),
      (_) => _tick(),
    );
  }

  void _tick() {
    if (_buffer.length < _minFrames) return;

    final packet = _buffer.removeAt(0);
    if (packet.isEmpty) return;

    final speakerId = packet[0];
    final payload = packet.sublist(1);
    if (payload.isEmpty) return;

    double volume;
    if (speakerId == 1) {
      volume = _mdMuted ? 0.0 : _mdVolume;
    } else {
      volume = _secondMuted ? 0.0 : _secondVolume;
    }

    Uint8List pcm;
    try {
      pcm = _codec.decodeFrame(payload);
    } catch (_) {
      return;
    }
    if (pcm.isEmpty) return;

    if (volume <= 0.0) return;
    if (volume < 1.0) pcm = _applyGain(pcm, volume);

    _channel.invokeMethod('write', {'data': pcm});
  }

  Uint8List _applyGain(Uint8List pcm, double gain) {
    final out = Uint8List(pcm.length);
    for (int i = 0; i + 1 < pcm.length; i += 2) {
      int sample = pcm[i] | (pcm[i + 1] << 8);
      if (sample >= 0x8000) sample -= 0x10000;
      int scaled = (sample * gain).round();
      if (scaled > 32767) scaled = 32767;
      if (scaled < -32768) scaled = -32768;
      out[i] = scaled & 0xFF;
      out[i + 1] = (scaled >> 8) & 0xFF;
    }
    return out;
  }

  /// Add a packet tagged with the speaker id as the first byte.
  void addPacket(Uint8List packet) {
    if (!_running) return;
    _buffer.add(packet);
    while (_buffer.length > _maxFrames) {
      _buffer.removeAt(0);
    }
  }

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _buffer.clear();
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  void dispose() {
    stop();
    _codec.dispose();
  }
}
