import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/gebruiker.dart';
import '../services/gebruiker_service.dart';
import 'pdf_test_screen.dart';

/// Startscherm na het inloggen.
///
/// Nu nog een simpele placeholder die het Firestore-profiel (naam + rol)
/// van de ingelogde gebruiker toont + een uitlogknop, als bevestiging dat
/// het datamodel uit stap 3 werkt. De echte inhoud (eigen diensten
/// bekijken, PDF uploaden, ...) komt in latere stappen van het bouwplan
/// (zie PROJECT_SPEC.md).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // `currentUser` is nooit null hier: AuthGate toont dit scherm alleen
    // wanneer er een ingelogde gebruiker is.
    final account = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mama\'s rooster app'),
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
        // haalOfMaakProfiel() leest het Firestore-document van dit account,
        // en maakt het aan (met rol 'lid') als het de allereerste keer is
        // dat dit account inlogt.
        child: FutureBuilder<Gebruiker>(
          future: GebruikerService.haalOfMaakProfiel(account),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kon het profiel niet laden uit Firestore:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }

            final profiel = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ingelogd als ${profiel.naam}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  profiel.isBeheerder ? 'Rol: beheerder' : 'Rol: lid',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                // Tijdelijke knop voor stap 4.1: PDF-parsing uitproberen.
                // Verdwijnt zodra het echte overzichtscherm er is.
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PdfTestScreen()),
                    );
                  },
                  child: const Text('PDF-rooster testen'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
