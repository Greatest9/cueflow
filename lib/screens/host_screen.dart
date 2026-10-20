import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/app_state.dart';
import '../services/audio_relay.dart';
import '../utils/network_utils.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final AudioRelay _relay = AudioRelay();
  String _hostIp = '';
  int _port = 8080;
  bool _isRunning = false;
  
  @override
  void initState() {
    super.initState();
    _initHost();
  }
  
  Future<void> _initHost() async {
    final ip = await NetworkUtils.getLocalIp();
    if (ip == '0.0.0.0') {
      final gateway = await NetworkUtils.getHotspotGateway();
      _hostIp = gateway;
    } else {
      _hostIp = ip;
    }
    setState(() {});
    context.read<AppState>().setHostIp(_hostIp);
    context.read<AppState>().setServer(_hostIp, _port);
  }
  
  Future<void> _startRelay() async {
    setState(() => _isRunning = true);
    context.read<AppState>().setRunning(true);
    context.read<AppState>().setStatus('Starting relay...');
    final success = await _relay.start(port: _port);
    if (success) {
      context.read<AppState>().setStatus('Relay running');
      _relay.clientCountStream.listen((count) {
        if (mounted) {
          context.read<AppState>().setConnectedCount(count);
        }
      });
    } else {
      context.read<AppState>().setStatus('Failed to start');
      setState(() => _isRunning = false);
      context.read<AppState>().setRunning(false);
    }
  }
  
  Future<void> _stopRelay() async {
    await _relay.stop();
    setState(() => _isRunning = false);
    context.read<AppState>().setRunning(false);
    context.read<AppState>().setStatus('Stopped');
    context.read<AppState>().setConnectedCount(0);
  }
  
  @override
  void dispose() {
    _stopRelay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    return WillPopScope(
      onWillPop: () async {
        if (_isRunning) {
          await _stopRelay();
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Host - Relay'),
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
                      const Text('Relay Address', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'ws://$_hostIp:$_port',
                        style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: 'ws://$_hostIp:$_port',
                        version: QrVersions.auto,
                        size: 160,
                      ),
                      const Text('Scan to connect', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Status'),
                          Text(appState.status,
                            style: TextStyle(
                              color: _isRunning ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Listeners Connected'),
                          Text('${appState.connectedCount}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Host IP'),
                          Text(_hostIp),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Port'),
                          Text('$_port'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isRunning ? _stopRelay : _startRelay,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: _isRunning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _isRunning ? 'STOP RELAY' : 'START RELAY',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep on charger • Phone in pocket/bag not ideal for host',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}