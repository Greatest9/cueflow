import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/app_state.dart';
import '../services/audio_client.dart';
import '../services/discovery_service.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  AudioClient? _client;
  bool _connected = false;
  String _serverUrl = '';

  final DiscoveryService _discovery = DiscoveryService();
  StreamSubscription<List<DiscoveredHost>>? _discoverySub;
  List<DiscoveredHost> _hosts = [];
  bool _scanning = true;
  bool _manuallyConfigured = false;

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '8080');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final appState = context.read<AppState>();
    _ipController.text = appState.serverIp;
    _portController.text = appState.serverPort.toString();

    if (appState.role == AppRole.host) return;

    if (_serverUrl.isNotEmpty && _manuallyConfigured) {
      _connectTo(_serverUrl);
    } else {
      _startDiscovery();
    }
  }

  void _startDiscovery() {
    _discoverySub?.cancel();
    setState(() {
      _scanning = true;
      _hosts = [];
    });
    _discoverySub = _discovery.discover().listen((hosts) {
      if (!mounted) return;
      setState(() {
        _hosts = hosts;
        _scanning = false;
      });
      final appState = context.read<AppState>();
      if (hosts.length == 1 &&
          !_connected &&
          !appState.isRunning &&
          appState.status != 'Connecting...') {
        _connectTo(hosts.first.wsUrl);
      }
    });
  }

  Future<void> _connectTo(String wsUrl) async {
    final appState = context.read<AppState>();
    _discoverySub?.cancel();
    _discovery.stopDiscovery();

    setState(() {
      _serverUrl = wsUrl;
      _connected = false;
      _scanning = false;
    });

    final uri = Uri.parse(wsUrl);
    appState.setServer(uri.host, uri.port);

    _client?.disconnect();
    _client = AudioClient(serverUrl: wsUrl, onAudioReceived: _onAudioReceived);

    String roleStr;
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

    appState.setStatus('Connecting…');
    final success = await _client!.connect(roleStr);
    if (!mounted) return;
    if (success) {
      setState(() => _connected = true);
      appState.setStatus('Connected');
      appState.setRunning(true);
    } else {
      appState.setStatus('Connection failed');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _connected) return;
      if (_serverUrl.startsWith('ws://')) _connectTo(_serverUrl);
    });
  }

  Future<void> _connectManual() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8080;
    if (ip.isEmpty) return;
    setState(() => _manuallyConfigured = true);
    await _connectTo('ws://$ip:$port');
  }

  void _onAudioReceived(Uint8List data, int speakerId) {
    // Phase 2: decode + jitter buffer + playback.
  }

  Future<void> _scanQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (result == null || result.isEmpty) return;
    var url = result.trim();
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = 'ws://$url';
    }
    setState(() => _manuallyConfigured = true);
    await _connectTo(url);
  }

  @override
  void dispose() {
    _discoverySub?.cancel();
    _discovery.stopDiscovery();
    _client?.disconnect();
    _ipController.dispose();
    _portController.dispose();
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

    final bool isSpeaker =
        appState.role == AppRole.md || appState.role == AppRole.second;

    return Scaffold(
      appBar: AppBar(
        title: Text('CueFlow - $roleTitle'),
        backgroundColor: roleColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(roleIcon, size: 56, color: roleColor),
                    const SizedBox(height: 8),
                    Text(roleTitle,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
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
                    if (_connected && _serverUrl.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(_serverUrl,
                          style: const TextStyle(
                              fontSize: 10, fontFamily: 'monospace')),
                    ],
                  ],
                ),
              ),
            ),
            if (!_connected) ...[
              const SizedBox(height: 16),
              _buildFinder(appState),
            ],
            const SizedBox(height: 16),
            if (_connected && isSpeaker)
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.mic, size: 48, color: Colors.green),
                      SizedBox(height: 8),
                      Text('MIC READY',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green)),
                      Text('Audio streaming arrives in Phase 2',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            if (_connected && appState.role == AppRole.listener)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Receiving cues. Volume controls arrive in Phase 2.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
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

  Widget _buildFinder(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Find Host',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_scanning)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Scanning for host on this network…'),
                ],
              )
            else if (_hosts.isEmpty)
              const Text(
                'No host found automatically. Enter the address manually or '
                'scan the Host QR (some hotspots block auto-discovery).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              ..._hosts.map(
                (h) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.router),
                  title: Text(h.name),
                  subtitle: Text(h.wsUrl),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _connectTo(h.wsUrl),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ipController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Host IP',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanQr,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _connectManual,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _startDiscovery,
              child: const Text('Rescan network'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Host QR')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null && value.isNotEmpty) {
              Navigator.pop(context, value);
              return;
            }
          }
        },
      ),
    );
  }
}
