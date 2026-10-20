import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/app_state.dart';
import '../services/audio_relay.dart';
import '../services/discovery_service.dart';
import '../services/network_service.dart';
import '../utils/network_utils.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final AudioRelay _relay = AudioRelay();
  final DiscoveryService _discovery = DiscoveryService();
  static const int _port = 8080;

  String _hostIp = '';
  bool _isRunning = false;
  bool _wifiOn = false;

  @override
  void initState() {
    super.initState();
    _initHost();
    NetworkService.wifiStateStream().listen((on) {
      if (!mounted) return;
      setState(() => _wifiOn = on);
      if (!on && _isRunning) {
        _stopRelay();
      }
      if (on) _refreshIp();
    });
  }

  Future<void> _refreshIp() async {
    final ip = await NetworkUtils.getLanIp();
    if (!mounted) return;
    setState(() => _hostIp = ip ?? '');
    if (ip != null) {
      context.read<AppState>().setHostIp(ip);
      context.read<AppState>().setServer(ip, _port);
    }
  }

  Future<void> _initHost() async {
    _wifiOn = await NetworkService.isWifiConnected();
    await _refreshIp();
  }

  Future<void> _startRelay() async {
    final wifiOn = await NetworkService.isWifiConnected();
    if (!wifiOn) {
      await _showHotspotPrompt();
      return;
    }

    final ip = await NetworkUtils.getLanIp();
    if (ip == null) {
      await _showHotspotPrompt(
        message: 'No network address found. Make sure the hotspot is on, '
            'then try again.',
      );
      return;
    }

    context.read<AppState>().setStatus('Starting relay…');
    final success = await _relay.start(port: _port);
    if (!success) {
      context.read<AppState>().setStatus('Failed to start');
      return;
    }

    await _discovery.advertise(port: _port);
    _relay.clientCountStream.listen((count) {
      if (mounted) context.read<AppState>().setConnectedCount(count);
    });

    if (!mounted) return;
    setState(() {
      _isRunning = true;
      _hostIp = ip;
    });
    context.read<AppState>().setHostIp(ip);
    context.read<AppState>().setServer(ip, _port);
    context.read<AppState>().setRunning(true);
    context.read<AppState>().setStatus('Relay running');
  }

  Future<void> _stopRelay() async {
    await _relay.stop();
    await _discovery.stopAdvertising();
    if (!mounted) return;
    setState(() => _isRunning = false);
    context.read<AppState>().setRunning(false);
    context.read<AppState>().setStatus('Stopped');
    context.read<AppState>().setConnectedCount(0);
  }

  Future<void> _showHotspotPrompt({String? message}) async {
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn on hotspot / WiFi'),
        content: Text(
          message ??
              'The Host must have its hotspot (or WiFi) on so other phones '
                  'can join before the relay can start.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Hotspot Settings'),
          ),
        ],
      ),
    );
    if (go == true) {
      await NetworkService.openHotspotSettings();
    }
  }

  @override
  void dispose() {
    _stopRelay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final addressValid = NetworkUtils.isValidLanIp(_hostIp);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _isRunning) _stopRelay();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Host - Relay')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_wifiOn)
                Card(
                  color: Colors.orange.withValues(alpha: 0.15),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'WiFi / hotspot is off. Turn it on to run the relay.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Relay Address',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (addressValid)
                        Text(
                          'ws://$_hostIp:$_port',
                          style: const TextStyle(
                              fontSize: 14, fontFamily: 'monospace'),
                        )
                      else
                        const Text(
                          'Not connected — turn on hotspot',
                          style: TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 16),
                      if (addressValid)
                        QrImageView(
                          data: 'ws://$_hostIp:$_port',
                          version: QrVersions.auto,
                          size: 160,
                        )
                      else
                        const SizedBox(height: 160),
                      const SizedBox(height: 8),
                      Text(
                        addressValid
                            ? 'Others auto-find this device, or scan the QR'
                            : 'Waiting for a network address',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
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
                          Text(
                            appState.status,
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
                          Text(
                            '${appState.connectedCount}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
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
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep on charger • Open air, not in a bag',
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
