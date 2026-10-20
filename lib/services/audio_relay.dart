import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ClientType { md, second, listener, unknown }

class RelayClient {
  final WebSocketChannel channel;
  final ClientType type;
  DateTime lastSeen;
  int packetCount;
  
  RelayClient(this.channel, this.type) 
    : lastSeen = DateTime.now(),
      packetCount = 0;
}

class AudioRelay {
  static final AudioRelay _instance = AudioRelay._internal();
  factory AudioRelay() => _instance;
  AudioRelay._internal();
  
  HttpServer? _server;
  final List<RelayClient> _clients = [];
  Timer? _heartbeatTimer;
  final StreamController<int> _clientCountController = StreamController<int>.broadcast();
  
  Stream<int> get clientCountStream => _clientCountController.stream;
  int get clientCount => _clients.where((c) => c.type == ClientType.listener).length;
  
  Future<bool> start({int port = 8080}) async {
    try {
      final handler = webSocketHandler((WebSocketChannel webSocket, String? protocol) {
        _handleConnection(webSocket);
      });
      
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      print('Relay started on port $port');
      
      _startHeartbeat();
      return true;
    } catch (e) {
      print('Failed to start relay: $e');
      return false;
    }
  }
  
  void _handleConnection(WebSocketChannel ws) {
    ClientType type = ClientType.unknown;
    ws.stream.listen(
      (message) {
        if (message is List<int>) {
          _handleMessage(ws, Uint8List.fromList(message));
        } else if (message is String) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'register') {
              final role = data['role'];
              if (role == 'md') type = ClientType.md;
              else if (role == 'second') type = ClientType.second;
              else if (role == 'listener') type = ClientType.listener;
              
              // Check if client already exists
              _removeClient(ws);
              _clients.add(RelayClient(ws, type));
              _clientCountController.add(clientCount);
              print('Client registered: $role, total listeners: $clientCount');
              return;
            }
          } catch (e) {}
        }
      },
      onDone: () {
        _removeClient(ws);
        _clientCountController.add(clientCount);
      },
      onError: (e) {
        _removeClient(ws);
        _clientCountController.add(clientCount);
      },
    );
  }
  
  void _handleMessage(WebSocketChannel senderWs, Uint8List data) {
    if (data.isEmpty) return;
    
    // Find sender
    RelayClient? sender;
    for (var c in _clients) {
      if (c.channel == senderWs) {
        sender = c;
        break;
      }
    }
    
    if (sender == null) return;
    if (sender.type == ClientType.listener) return; // listeners can't send
    if (sender.type == ClientType.unknown) return;
    
    sender.lastSeen = DateTime.now();
    sender.packetCount++;
    
    // Tag packet: [speakerId(1), ...audioData]
    int speakerId = sender.type == ClientType.md ? 1 : 2;
    final tagged = Uint8List(1 + data.length);
    tagged[0] = speakerId;
    tagged.setRange(1, 1 + data.length, data);
    
    // Forward to all other clients
    for (var client in List.from(_clients)) {
      if (client.channel != senderWs) {
        try {
          client.channel.sink.add(tagged);
        } catch (e) {
          _removeClient(client.channel);
        }
      }
    }
  }
  
  void _removeClient(WebSocketChannel ws) {
    _clients.removeWhere((c) => c.channel == ws);
  }
  
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final now = DateTime.now();
      for (var client in List.from(_clients)) {
        if (now.difference(client.lastSeen).inSeconds > 10) {
          try {
            client.channel.sink.close();
          } catch (e) {}
          _removeClient(client.channel);
        }
      }
      _clientCountController.add(clientCount);
    });
  }
  
  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    for (var client in _clients) {
      try {
        await client.channel.sink.close();
      } catch (e) {}
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }
}