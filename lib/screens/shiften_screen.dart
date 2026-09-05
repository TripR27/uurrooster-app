import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../services/dienst_service.dart';
import '../theme.dart';
import '../widgets/dienst_tile.dart';
import 'dienst_bewerken_screen.dart';

/// Scherm met de eigen shiften van de ingelogde gebruiker: een live lijst
/// (`DienstService.eigenDiensten`) waarbij elke rij open te tikken is om te
/// corrigeren/verwijderen (zie PROJECT_SPEC.md sectie 1 - PDF-import mag
/// nooit de enige manier zijn waarop een shift ontstaat of verandert).
///
/// Vroeger stond deze lijst rechtstreeks op [HomeScreen] (in
/// `_EigenRooster`); dat scherm toont nu enkel nog 2 knoppen, waarvan deze
/// lijst er ("Shiften bekijken") één is - zie PROJECT_SPEC.md sectie 13.
class ShiftenScreen extends StatelessWidget {
  const ShiftenScreen({super.key, required this.profiel});

  final Gebruiker profiel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mijn shiften')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppKleuren.bosgroenDonker,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(
              children: [
                const Icon(
                  Icons.event_note,
                  color: AppKleuren.terracotta,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Alles wat er voor jou op de kalender staat',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Dienst>>(
              stream: DienstService.eigenDiensten(profiel.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Kon shiften niet laden: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  );
                }
                final diensten = snapshot.data ?? [];
                if (diensten.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nog geen shiften. Upload een PDF-rooster om te '
                        'beginnen.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: diensten.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
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
