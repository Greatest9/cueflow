import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
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
              onTap: () {
                appState.setRole(AppRole.md);
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
              onTap: () {
                appState.setRole(AppRole.second);
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
              onTap: () {
                appState.setRole(AppRole.listener);
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
                backgroundColor: color.withOpacity(0.2),
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