import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/audio_client.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  AudioClient? _client;
  bool _connected = false;
  String _serverUrl = '';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initConnection();
    });
  }
  
  void _initConnection() {
    final appState = context.read<AppState>();
    setState(() {
      _serverUrl = 'ws://${appState.serverIp}:${appState.serverPort}';
    });
    
    _client = AudioClient(
      serverUrl: _serverUrl,
      onAudioReceived: _onAudioReceived,
    );
    
    _connect();
  }
  
  Future<void> _connect() async {
    final appState = context.read<AppState>();
    String roleStr = '';
    switch (appState.role) {
      case AppRole.md:
        roleStr = 'md';
        break;
      case AppRole.second:
        roleStr = 'second';
        break;
      case AppRole.listener:
        roleStr = 'listener';
        break;
      case AppRole.host:
        roleStr = 'host';
        break;
    }
    
    appState.setStatus('Connecting...');
    final success = await _client!.connect(roleStr);
    if (success) {
      setState(() => _connected = true);
      appState.setStatus('Connected');
    } else {
      appState.setStatus('Connection failed');
      // Retry after 2 seconds
      Timer(const Duration(seconds: 2), _connect);
    }
  }
  
  void _onAudioReceived(Uint8List data, int speakerId) {
    // TODO: Decode and play audio
    // For now just acknowledge
  }
  
  @override
  void dispose() {
    _client?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    String roleTitle = '';
    IconData roleIcon = Icons.headset;
    Color roleColor = Colors.blue;
    
    switch (appState.role) {
      case AppRole.md:
        roleTitle = 'MD';
        roleIcon = Icons.record_voice_over;
        roleColor = Colors.red;
        break;
      case AppRole.second:
        roleTitle = 'SECOND';
        roleIcon = Icons.voice_chat;
        roleColor = Colors.orange;
        break;
      case AppRole.listener:
        roleTitle = 'LISTENER';
        roleIcon = Icons.headset;
        roleColor = Colors.blue;
        break;
      case AppRole.host:
        roleTitle = 'HOST';
        roleIcon = Icons.router;
        roleColor = Colors.purple;
        break;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('CueFlow - $roleTitle'),
        backgroundColor: roleColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(roleIcon, size: 64, color: roleColor),
                    const SizedBox(height: 8),
                    Text(roleTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _connected ? Icons.check_circle : Icons.error,
                          color: _connected ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(appState.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$_serverUrl', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (appState.role == AppRole.md || appState.role == AppRole.second)
              Card(
                color: Colors.green.withOpacity(0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.mic, size: 48, color: Colors.green),
                      SizedBox(height: 8),
                      Text('MIC ACTIVE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      Text('Speak into your earpiece mic', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            if (appState.role == AppRole.listener)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mix Controls', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(width: 60, child: Text('MD')),
                          Expanded(
                            child: Slider(
                              value: appState.mdVolume,
                              onChanged: (v) => appState.setMdVolume(v),
                            ),
                          ),
                          IconButton(
                            icon: Icon(appState.mdMuted ? Icons.volume_off : Icons.volume_up),
                            onPressed: () => appState.setMdMuted(!appState.mdMuted),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 60, child: Text('Second')),
                          Expanded(
                            child: Slider(
                              value: appState.secondVolume,
                              onChanged: (v) => appState.setSecondVolume(v),
                            ),
                          ),
                          IconButton(
                            icon: Icon(appState.secondMuted ? Icons.volume_off : Icons.volume_up),
                            onPressed: () => appState.setSecondMuted(!appState.secondMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            if (!_connected)
              ElevatedButton(
                onPressed: _connect,
                child: const Text('RECONNECT'),
              ),
            const SizedBox(height: 8),
            const Text(
              'Keep screen off or in pocket • Open mic active',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}