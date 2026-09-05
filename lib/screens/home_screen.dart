import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../services/dienst_service.dart';
import '../services/gebruiker_service.dart';
import '../widgets/dienst_tile.dart';
import 'dienst_bewerken_screen.dart';
import 'pdf_upload_screen.dart';

/// Startscherm na het inloggen: wie ben je + je eigen diensten, met de
/// mogelijkheid om een dienst te openen om te corrigeren/verwijderen (zie
/// PROJECT_SPEC.md sectie 1 - PDF-import mag nooit de enige manier zijn
/// waarop een dienst ontstaat of verandert).
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
      // haalOfMaakProfiel() leest het Firestore-document van dit account,
      // en maakt het aan (met rol 'lid') als het de allereerste keer is
      // dat dit account inlogt.
      body: FutureBuilder<Gebruiker>(
        future: GebruikerService.haalOfMaakProfiel(account),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kon het profiel niet laden:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }

          final profiel = snapshot.data!;
          return _EigenRooster(profiel: profiel);
        },
      ),
    );
  }
}

class _EigenRooster extends StatelessWidget {
  const _EigenRooster({required this.profiel});

  final Gebruiker profiel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ingelogd als ${profiel.naam}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            profiel.isBeheerder ? 'Rol: beheerder' : 'Rol: lid',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('PDF-rooster uploaden'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PdfUploadScreen(profiel: profiel),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Mijn diensten', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<Dienst>>(
              stream: DienstService.eigenDiensten(profiel.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text(
                    'Kon diensten niet laden: ${snapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
                final diensten = snapshot.data ?? [];
                if (diensten.isEmpty) {
                  return const Text(
                    'Nog geen diensten. Upload een PDF-rooster om te '
                    'beginnen.',
                  );
                }
                return ListView.builder(
                  itemCount: diensten.length,
                  itemBuilder: (context, i) => DienstTile(
                    dienst: diensten[i],
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DienstBewerkenScreen(dienst: diensten[i]),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
