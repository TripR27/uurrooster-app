import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Startscherm na het inloggen.
///
/// Nu nog een simpele placeholder die bevestigt wie er is ingelogd + een
/// uitlogknop. De echte inhoud (eigen diensten bekijken, PDF uploaden, ...)
/// komt in latere stappen van het bouwplan (zie PROJECT_SPEC.md).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // `currentUser` is nooit null hier: AuthGate toont dit scherm alleen
    // wanneer er een ingelogde gebruiker is.
    final gebruiker = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gezinsrooster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Uitloggen',
            onPressed: () => FirebaseAuth.instance.signOut(),
            // Na signOut() verandert authStateChanges() van waarde en toont
            // AuthGate automatisch weer het inlogscherm.
          ),
        ],
      ),
      body: Center(
        child: Text('Ingelogd als ${gebruiker.email}'),
      ),
    );
  }
}
