import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'providers/agent_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Graceful fallback if firebase is not configured in local environment yet
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AgentStateProvider()),
      ],
      child: const OptiFlowApp(),
    ),
  );
}

class OptiFlowApp extends StatelessWidget {
  const OptiFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OptiFlow',
      theme: AppTheme.light,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
