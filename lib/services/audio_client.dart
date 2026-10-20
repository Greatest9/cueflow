import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum SpeakerId { md, second, none }

class AudioClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final Function(Uint8List taggedPacket) onAudioReceived;
  String serverUrl;
  VoidCallback? onDisconnected;
  
  AudioClient({required this.serverUrl, required this.onAudioReceived, this.onDisconnected});
  
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
            if (data.length < 2) return;
            onAudioReceived(data);
          }
        },
        onError: (e) {
          print('WebSocket error: $e');
          onDisconnected?.call();
        },
        onDone: () {
          print('WebSocket disconnected');
          onDisconnected?.call();
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