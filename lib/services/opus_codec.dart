import 'dart:typed_data';
import 'package:flutter_opus/flutter_opus.dart';

class OpusCodec {
  static const int sampleRate = 48000;
  static const int channels = 1;
  static const int frameMs = 20;
  static const int frameSamples = sampleRate * frameMs ~/ 1000;
  static const int bitrate = 32000;

  OpusEncoder? _encoder;
  OpusDecoder? _decoder;

  OpusEncoder get encoder {
    var enc = _encoder;
    if (enc == null) {
      enc = OpusEncoder.create(
        sampleRate: sampleRate,
        channels: channels,
      );
      if (enc == null) {
        throw StateError('Failed to create Opus encoder');
      }
      enc.setBitrate(bitrate);
      enc.setComplexity(5);
      _encoder = enc;
    }
    return enc;
  }

  OpusDecoder get decoder {
    var dec = _decoder;
    if (dec == null) {
      dec = OpusDecoder.create(sampleRate: sampleRate, channels: channels);
      if (dec == null) {
        throw StateError('Failed to create Opus decoder');
      }
      _decoder = dec;
    }
    return dec;
  }

  Uint8List encodeFrame(Int16List pcm) {
    final out = encoder.encode(pcm, frameSamples);
    if (out == null) return Uint8List(0);
    return Uint8List.fromList(out);
  }

  Uint8List decodeFrame(Uint8List opusData) {
    final pcm = decoder.decode(opusData, frameSamples);
    if (pcm == null) return Uint8List(0);
    return pcm;
  }

  void dispose() {
    _encoder?.dispose();
    _decoder?.dispose();
    _encoder = null;
    _decoder = null;
  }
}
