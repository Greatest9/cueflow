import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

enum SpeakerId { md, second, none }

class AudioClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final Function(Uint8List data, int speakerId) onAudioReceived;
  String serverUrl;
  
  AudioClient({required this.serverUrl, required this.onAudioReceived});
  
  Future<bool> connect(String role) async {
    try {
      final uri = Uri.parse(serverUrl);
      _channel = WebSocketChannel.connect(uri);
      
      // Register role
      await _channel!.ready;
      _channel!.sink.add('{"type":"register","role":"$role"}');
      
      _subscription = _channel!.stream.listen(
        (message) {
          if (message is List<int>) {
            final data = Uint8List.fromList(message);
            if (data.isEmpty) return;
            final speakerId = data[0];
            final audioData = data.sublist(1);
            if (audioData.isNotEmpty) {
              onAudioReceived(audioData, speakerId);
            }
          }
        },
        onError: (e) {
          print('WebSocket error: $e');
        },
        onDone: () {
          print('WebSocket disconnected');
        },
      );
      
      return true;
    } catch (e) {
      print('Connection failed: $e');
      return false;
    }
  }
  
  void sendAudio(Uint8List data) {
    if (_channel != null) {
      try {
        _channel!.sink.add(data);
      } catch (e) {
        print('Send error: $e');
      }
    }
  }
  
  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
  
  bool get isConnected => _channel != null;
}