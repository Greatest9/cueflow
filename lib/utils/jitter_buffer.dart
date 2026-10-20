import 'dart:async';
import 'dart:typed_data';

class JitterBuffer {
  final int maxFrames;
  final int minFrames;
  final int frameSize;
  final List<Uint8List> _buffer = [];
  late final StreamController<Uint8List> _out;
  Timer? _timer;
  bool _running = false;
  
  JitterBuffer({
    this.minFrames = 4,
    this.maxFrames = 8,
    this.frameSize = 320,
  }) {
    _out = StreamController<Uint8List>.broadcast();
  }
  
  Stream<Uint8List> get stream => _out.stream;
  
  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (_buffer.isNotEmpty && _buffer.length >= minFrames) {
        final frame = _buffer.removeAt(0);
        if (!_out.isClosed) {
          _out.add(frame);
        }
      } else if (_buffer.length > maxFrames) {
        _buffer.removeAt(0);
      }
    });
  }
  
  void stop() {
    _running = false;
    _timer?.cancel();
    _buffer.clear();
  }
  
  void add(Uint8List data) {
    if (_buffer.length < maxFrames * 2) {
      _buffer.add(data);
    }
  }
  
  void dispose() {
    stop();
    _out.close();
  }
}