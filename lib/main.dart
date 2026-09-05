import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';

void main() async {
  // Nodig omdat Firebase.initializeApp() al Flutter-bindings gebruikt
  // vóórdat runApp() dat normaal gesproken zelf zou doen.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gezinsrooster',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // AuthGate beslist zelf of het inlogscherm of het startscherm getoond
      // wordt, op basis van de Firebase-inlogstatus (zie auth_gate.dart).
      home: const AuthGate(),
    );
  }
}
