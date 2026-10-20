import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/network_service.dart';
import '../utils/network_utils.dart';
import 'host_screen.dart';
import 'service_screen.dart';

class RolePickerScreen extends StatefulWidget {
  const RolePickerScreen({super.key});

  @override
  State<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends State<RolePickerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadPrefs();
    });
  }

  Future<bool> _ensureWifi({required bool isHost}) async {
    final connected = await NetworkService.isWifiConnected();
    if (connected) return true;
    if (!mounted) return false;
    final goSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHost ? 'Turn on hotspot / WiFi' : 'Turn on WiFi'),
        content: Text(
          isHost
              ? 'The Host must have its hotspot (or WiFi) on so other phones can join.'
              : 'Connect this phone to the Host\'s WiFi/hotspot before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHost ? 'Open Hotspot Settings' : 'Open WiFi Settings'),
          ),
        ],
      ),
    );
    if (goSettings == true) {
      if (isHost) {
        await NetworkService.openHotspotSettings();
      } else {
        await NetworkService.openWifiSettings();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('CueFlow'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Role',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _RoleButton(
              title: 'HOST',
              subtitle: 'Run relay on this phone (hotspot)',
              icon: Icons.router,
              color: Colors.purple,
              onTap: () async {
                if (!await _ensureWifi(isHost: true)) return;
                appState.setRole(AppRole.host);
                final ip = await NetworkUtils.getLocalIp();
                appState.setHostIp(ip);
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HostScreen()),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _RoleButton(
              title: 'MD',
              subtitle: 'Music Director - speak cues',
              icon: Icons.record_voice_over,
              color: Colors.red,
              onTap: () async {
                if (!await _ensureWifi(isHost: false)) return;
                appState.setRole(AppRole.md);
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServiceScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _RoleButton(
              title: 'SECOND',
              subtitle: 'Second speaker - speak cues',
              icon: Icons.voice_chat,
              color: Colors.orange,
              onTap: () async {
                if (!await _ensureWifi(isHost: false)) return;
                appState.setRole(AppRole.second);
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServiceScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _RoleButton(
              title: 'LISTENER',
              subtitle: 'Receive cues only',
              icon: Icons.headset,
              color: Colors.blue,
              onTap: () async {
                if (!await _ensureWifi(isHost: false)) return;
                appState.setRole(AppRole.listener);
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServiceScreen()),
                );
              },
            ),
            const Spacer(),
            const Text(
              'Band: 2 Keyboards • Bass • Semi-Acoustic • Lead Guitar • Drums • Sax • Conga',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  
  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.2),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}