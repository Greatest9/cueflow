import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/role_picker_screen.dart';
import 'services/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.init();
  runApp(const CueFlowApp());
}

class CueFlowApp extends StatelessWidget {
  const CueFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'CueFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
        ),
        home: const RolePickerScreen(),
      ),
    );
  }
}