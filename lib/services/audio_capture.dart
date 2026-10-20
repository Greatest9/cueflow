import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'opus_codec.dart';

class AudioCapture {
  final AudioRecorder _recorder = AudioRecorder();
  final OpusCodec _codec = OpusCodec();

  final void Function(Uint8List opusFrame) onFrame;

  StreamSubscription<Uint8List>? _sub;
  Int16List _carry = Int16List(0);
  bool _running = false;

  AudioCapture({required this.onFrame});

  bool get isRunning => _running;

  Future<bool> start() async {
    if (_running) return true;
    if (!await _recorder.hasPermission()) return false;

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: OpusCodec.sampleRate,
        numChannels: OpusCodec.channels,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        streamBufferSize: 4096,
      ),
    );

    _running = true;
    _sub = stream.listen(_onData, onError: (_) {}, cancelOnError: false);
    return true;
  }

  void _onData(Uint8List bytes) {
    if (!_running || bytes.isEmpty) return;

    final samples = _bytesToInt16(bytes);
    final combined = Int16List(_carry.length + samples.length);
    combined.setAll(0, _carry);
    combined.setAll(_carry.length, samples);

    final frameSamples = OpusCodec.frameSamples;
    int offset = 0;
    while (combined.length - offset >= frameSamples) {
      final frame = Int16List(frameSamples);
      frame.setAll(0, combined.sublist(offset, offset + frameSamples));
      offset += frameSamples;
      _encodeAndSend(frame);
    }

    if (offset < combined.length) {
      _carry = combined.sublist(offset);
    } else {
      _carry = Int16List(0);
    }
  }

  void _encodeAndSend(Int16List frame) {
    try {
      final opus = _codec.encodeFrame(frame);
      if (opus.isNotEmpty) onFrame(opus);
    } catch (_) {}
  }

  Int16List _bytesToInt16(Uint8List bytes) {
    final count = bytes.length ~/ 2;
    final out = Int16List(count);
    for (int i = 0; i < count; i++) {
      int sample = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
      if (sample >= 0x8000) sample -= 0x10000;
      out[i] = sample;
    }
    return out;
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    _carry = Int16List(0);
  }

  Future<void> dispose() async {
    await stop();
    _codec.dispose();
    await _recorder.dispose();
  }
}
