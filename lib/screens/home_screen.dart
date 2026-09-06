import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../services/dienst_service.dart';
import '../services/gebruiker_service.dart';
import '../theme.dart';
import '../util/datum_util.dart';
import 'beheer_overzicht_screen.dart';
import 'pdf_upload_screen.dart';
import 'shiften_screen.dart';

/// Startscherm na het inloggen: wie ben je, en van daaruit met 2 duidelijke
/// knoppen naar "PDF uploaden" (PdfUploadScreen) of "Shiften bekijken"
/// (ShiftenScreen, die zelf toelaat om een shift te corrigeren/verwijderen -
/// zie PROJECT_SPEC.md §1, PDF-import mag nooit de enige manier zijn
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
                onTap: () async {
                  // PdfUploadScreen gaat na een geslaagde opslag meteen
                  // terug naar hier (Navigator.pop met het aantal
                  // opgeslagen shiften) i.p.v. zelf een "opgeslagen"-tekst
                  // te tonen - beter leesbaar, en hier meteen bevestigen.
                  final aantalOpgeslagen = await Navigator.of(context)
                      .push<int>(
                        MaterialPageRoute(
                          builder: (_) => PdfUploadScreen(profiel: profiel),
                        ),
                      );
                  if (aantalOpgeslagen != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$aantalOpgeslagen shiften opgeslagen.'),
                      ),
                    );
                  }
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
              const SizedBox(height: 28),
              Text(
                'Volgende shift',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _VolgendeShiftKaart(profiel: profiel),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vult de lege ruimte onder de menukaarten met iets nuttigs i.p.v. gewoon
/// wit/leeg: een vooruitblik op de eerstvolgende (vandaag of later) shift
/// van de ingelogde gebruiker, live bijgewerkt via dezelfde stream als
/// ShiftenScreen.
class _VolgendeShiftKaart extends StatelessWidget {
  const _VolgendeShiftKaart({required this.profiel});

  final Gebruiker profiel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Dienst>>(
      stream: DienstService.eigenDiensten(profiel.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _KaartFrame(
            icoon: Icons.hourglass_empty,
            kleur: AppKleuren.bosgroen,
            titel: 'Even geduld...',
            inhoud: '',
          );
        }

        final vandaag = naarIsoDatum(DateTime.now());
        // Ook een meerdaagse periode die nu bezig is (begonnen in het
        // verleden, eindigt vandaag of later) telt als "aankomend".
        final volgende = (snapshot.data ?? [])
            .where((d) => (d.eindDatum ?? d.datum).compareTo(vandaag) >= 0)
            .toList();

        if (volgende.isEmpty) {
          return const _KaartFrame(
            icoon: Icons.beach_access,
            kleur: AppKleuren.terracotta,
            titel: 'Niks gepland',
            inhoud: 'Geen aankomende shiften - geniet van je vrije tijd!',
          );
        }

        final eerst = volgende.first;
        return _KaartFrame(
          icoon: Icons.event_available,
          kleur: AppKleuren.bosgroen,
          titel: eerst.valtOpDatum(vandaag)
              ? (eerst.isMeerdaags ? 'Bezig' : 'Vandaag')
              : _naarRelatieveDag(eerst.datum),
          inhoud: eerst.naarTekst(),
        );
      },
    );
  }

  /// "Vandaag"/"Morgen" i.p.v. een kale datum wanneer relevant - dat leest
  /// sneller dan zelf de datum van vandaag moeten aftrekken.
  String _naarRelatieveDag(String iso) {
    final vandaag = DateTime.now();
    final dag = vanIsoDatum(iso);
    final verschilInDagen = DateTime(
      dag.year,
      dag.month,
      dag.day,
    ).difference(DateTime(vandaag.year, vandaag.month, vandaag.day)).inDays;
    switch (verschilInDagen) {
      case 0:
        return 'Vandaag';
      case 1:
        return 'Morgen';
      default:
        return naarWeergaveDatum(iso);
    }
  }
}

/// Zelfde kaart-uiterlijk als [_MenuKaart] (wit, afgeronde hoeken, gekleurd
/// icoon-vakje) maar dan niet-tikbaar, puur om info te tonen.
class _KaartFrame extends StatelessWidget {
  const _KaartFrame({
    required this.icoon,
    required this.kleur,
    required this.titel,
    required this.inhoud,
  });

  final IconData icoon;
  final Color kleur;
  final String titel;
  final String inhoud;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
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
                  if (inhoud.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(inhoud, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
