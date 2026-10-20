import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/app_state.dart';
import '../services/audio_capture.dart';
import '../services/audio_client.dart';
import '../services/audio_playback.dart';
import '../services/discovery_service.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  AudioClient? _client;
  AudioCapture? _capture;
  final AudioPlayback _playback = AudioPlayback();
  bool _connected = false;
  String _serverUrl = '';
  bool _capturing = false;

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
    await _capture?.stop();
    _client = AudioClient(
      serverUrl: wsUrl,
      onAudioReceived: _onAudioReceived,
      onDisconnected: _onDisconnected,
    );

    _playback.setVolumes(
      md: appState.mdVolume,
      second: appState.secondVolume,
      mdMuted: appState.mdMuted,
      secondMuted: appState.secondMuted,
    );
    _playback.setJitter(appState.jitterBufferMs);

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
      await _playback.start();
      if (isSpeakerRole(appState.role)) {
        await _startCapture();
      }
    } else {
      appState.setStatus('Connection failed');
      _scheduleReconnect();
    }
  }

  bool isSpeakerRole(AppRole role) =>
      role == AppRole.md || role == AppRole.second;

  Future<void> _startCapture() async {
    final appState = context.read<AppState>();
    _capture = AudioCapture(
      onFrame: (frame) {
        final tagged = Uint8List(1 + frame.length);
        tagged[0] = appState.role == AppRole.md ? 1 : 2;
        tagged.setRange(1, 1 + frame.length, frame);
        _client?.sendAudio(tagged);
      },
    );
    final ok = await _capture!.start();
    if (!mounted) return;
    setState(() => _capturing = ok);
    if (!ok) appState.setStatus('Mic unavailable');
  }

  void _onDisconnected() {
    if (!mounted) return;
    setState(() => _connected = false);
    context.read<AppState>().setStatus('Disconnected');
    _scheduleReconnect();
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

  void _onAudioReceived(Uint8List taggedPacket) {
    _playback.addPacket(taggedPacket);
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
    _capture?.stop();
    _client?.disconnect();
    _playback.dispose();
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
            if (_connected && isSpeaker) _buildSpeakerCard(),
            if (_connected && appState.role == AppRole.listener) ...[
              _buildListenerCard(appState),
              _buildVolumeControls(appState),
            ],
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

  Widget _buildSpeakerCard() {
    return Card(
      color: (_capturing ? Colors.green : Colors.orange).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              _capturing ? Icons.mic : Icons.mic_off,
              size: 48,
              color: _capturing ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 8),
            Text(
              _capturing ? 'MIC LIVE' : 'MIC STARTING…',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _capturing ? Colors.green : Colors.orange,
              ),
            ),
            const Text(
              'Open mic — speaking now transmits to the band',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListenerCard(AppState appState) {
    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.headset, size: 40, color: Colors.green),
            SizedBox(height: 8),
            Text('RECEIVING CUES',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeControls(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Mix', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    appState.mdMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.red,
                  ),
                  onPressed: () => appState.setMdMuted(!appState.mdMuted),
                ),
                const SizedBox(width: 4),
                const SizedBox(width: 56, child: Text('MD')),
                Expanded(
                  child: Slider(
                    value: appState.mdVolume,
                    onChanged: (v) {
                      appState.setMdVolume(v);
                      _syncVolumes(appState);
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    appState.secondMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.orange,
                  ),
                  onPressed: () =>
                      appState.setSecondMuted(!appState.secondMuted),
                ),
                const SizedBox(width: 4),
                const SizedBox(width: 56, child: Text('SECOND')),
                Expanded(
                  child: Slider(
                    value: appState.secondVolume,
                    onChanged: (v) {
                      appState.setSecondVolume(v);
                      _syncVolumes(appState);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _syncVolumes(AppState appState) {
    _playback.setVolumes(
      md: appState.mdVolume,
      second: appState.secondVolume,
      mdMuted: appState.mdMuted,
      secondMuted: appState.secondMuted,
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
