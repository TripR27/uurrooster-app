import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/gebruiker.dart';
import '../services/gebruiker_service.dart';
import '../theme.dart';
import 'beheer_overzicht_screen.dart';
import 'pdf_upload_screen.dart';
import 'shiften_screen.dart';

/// Startscherm na het inloggen: wie ben je, en van daaruit met 2 duidelijke
/// knoppen naar "PDF uploaden" (PdfUploadScreen) of "Shiften bekijken"
/// (ShiftenScreen, die zelf toelaat om een shift te corrigeren/verwijderen -
/// zie PROJECT_SPEC.md sectie 1, PDF-import mag nooit de enige manier zijn
/// waarop een shift ontstaat of verandert).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // `currentUser` is nooit null hier: AuthGate toont dit scherm alleen
    // wanneer er een ingelogde gebruiker is.
    final account = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      // Geen losse AppBar: de uitlog-knop zit mee in de gekleurde kop
      // hieronder, in dezelfde bosgroene sfeer als het inlogscherm.
      body: SafeArea(
        // haalOfMaakProfiel() leest het Firestore-document van dit account,
        // en maakt het aan (met rol 'lid') als het de allereerste keer is
        // dat dit account inlogt.
        child: FutureBuilder<Gebruiker>(
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              );
            }

            final profiel = snapshot.data!;
            return _StartMenu(profiel: profiel);
          },
        ),
      ),
    );
  }
}

class _StartMenu extends StatelessWidget {
  const _StartMenu({required this.profiel});

  final Gebruiker profiel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Kop(profiel: profiel),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _MenuKaart(
                icoon: Icons.upload_file,
                titel: 'PDF uploaden',
                omschrijving: 'Je werkrooster inlezen uit een PDF-bestand',
                kleur: AppKleuren.terracotta,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PdfUploadScreen(profiel: profiel),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _MenuKaart(
                icoon: Icons.event_note,
                titel: 'Shiften bekijken',
                omschrijving:
                    'Je eigen shiften bekijken, corrigeren of '
                    'verwijderen',
                kleur: AppKleuren.bosgroen,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShiftenScreen(profiel: profiel),
                    ),
                  );
                },
              ),
              if (profiel.isBeheerder) ...[
                const SizedBox(height: 16),
                _MenuKaart(
                  icoon: Icons.groups,
                  titel: 'Gezamenlijk overzicht',
                  omschrijving: 'Rooster van iedereen samen bekijken',
                  kleur: AppKleuren.inkt,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BeheerOverzichtScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Gekleurde kop met wie ingelogd is + uitlog-knop, in dezelfde bosgroene
/// sfeer als het brandingpaneel op het inlogscherm (zie login_screen.dart) -
/// zodat het startscherm niet "vlak" oogt naast dat scherm.
class _Kop extends StatelessWidget {
  const _Kop({required this.profiel});

  final Gebruiker profiel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppKleuren.bosgroenDonker, AppKleuren.bosgroen],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 8, 28),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month,
              color: AppKleuren.terracotta,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mama\'s rooster app',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Text(
                    'Hoi, ${profiel.naam}!',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      profiel.isBeheerder ? 'Beheerder' : 'Gezinslid',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Uitloggen',
              onPressed: () => FirebaseAuth.instance.signOut(),
              // Na signOut() verandert authStateChanges() van waarde en
              // toont AuthGate automatisch weer het inlogscherm.
            ),
          ],
        ),
      ),
    );
  }
}

/// Eén grote tikbare kaart voor één van de twee hoofdacties op het
/// startscherm ("PDF uploaden" / "Shiften bekijken").
class _MenuKaart extends StatelessWidget {
  const _MenuKaart({
    required this.icoon,
    required this.titel,
    required this.omschrijving,
    required this.kleur,
    required this.onTap,
  });

  final IconData icoon;
  final String titel;
  final String omschrijving;
  final Color kleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: kleur.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icoon, color: kleur, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      omschrijving,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
