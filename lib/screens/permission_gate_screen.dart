import 'package:flutter/material.dart';
import '../utils/permissions_helper.dart';
import 'role_picker_screen.dart';

class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _checking = true);
    final result = await PermissionsHelper.requestAll();
    if (!mounted) return;
    if (result.allCriticalGranted) {
      _goNext();
    } else {
      setState(() {
        _checking = false;
      });
    }
  }

  void _goNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RolePickerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _checking
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Requesting permissions…'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic_off, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Microphone permission is required',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'CueFlow needs microphone access to transmit cues. '
                      'Notification and battery permissions keep audio alive '
                      'with the screen off.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _run,
                      child: const Text('Grant Permissions'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
