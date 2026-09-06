import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../print/printen.dart';
import '../services/dienst_service.dart';
import '../services/gebruiker_service.dart';
import '../theme.dart';
import '../util/datum_util.dart';
import 'dienst_bewerken_screen.dart';
import 'dienst_toevoegen_screen.dart';

/// Gezamenlijk overzicht van alle gezinsleden, enkel voor de beheerder (zie
/// PROJECT_SPEC.md §2 en §5) - een lijst dag-kaarten (1 regel per gezinslid)
/// voor de gekozen maand, met een knop om dat rechtstreeks af te drukken
/// (§7). De beheerder kan hier ook shiften van iedereen toevoegen,
/// corrigeren of verwijderen (F3): tik een regel aan, of gebruik de
/// "Toevoegen"-knop.
class BeheerOverzichtScreen extends StatefulWidget {
  const BeheerOverzichtScreen({super.key, required this.profiel});

  /// De ingelogde beheerder.
  final Gebruiker profiel;

  @override
  State<BeheerOverzichtScreen> createState() => _BeheerOverzichtScreenState();
}

class _BeheerOverzichtScreenState extends State<BeheerOverzichtScreen> {
  late DateTime _maandStart;
  late Future<_Overzicht> _overzicht;
  bool _bezigMetPrinten = false;

  @override
  void initState() {
    super.initState();
    final vandaag = DateTime.now();
    _maandStart = DateTime(vandaag.year, vandaag.month);
    _overzicht = _laadOverzicht();
  }

  /// Laatste dag van [_maandStart] - dag 0 van de volgende maand is de
  /// laatste dag van de huidige, een gekende Dart-datum-truc.
  DateTime get _maandEinde =>
      DateTime(_maandStart.year, _maandStart.month + 1, 0);

  Future<_Overzicht> _laadOverzicht() async {
    final gebruikers = await GebruikerService.alleGebruikers();
    final diensten = await DienstService.voorPeriode(
      gebruikerIds: gebruikers.map((g) => g.uid).toList(),
      vanIso: naarIsoDatum(_maandStart),
      totIso: naarIsoDatum(_maandEinde),
    );
    return _Overzicht(gebruikers: gebruikers, diensten: diensten);
  }

  void _herlaad() {
    if (!mounted) return;
    // Block-body: een arrow `() => _overzicht = _laadOverzicht()` zou de
    // Future teruggeven en dan verwerpt setState() dat.
    setState(() {
      _overzicht = _laadOverzicht();
    });
  }

  void _wisselMaand(int aantalMaanden) {
    setState(() {
      _maandStart = DateTime(
        _maandStart.year,
        _maandStart.month + aantalMaanden,
      );
      _overzicht = _laadOverzicht();
    });
  }

  /// Print/deelt het overzicht van de huidig geladen maand - op web
  /// rechtstreeks naar de systeem-printdialoog, op Android via een
  /// gegenereerde PDF + het deel-scherm (zie `lib/print/printen.dart`).
  Future<void> _printen() async {
    setState(() => _bezigMetPrinten = true);
    try {
      final overzicht = await _overzicht;
      await printOverzicht(
        maandStart: _maandStart,
        gebruikers: overzicht.gebruikers,
        diensten: overzicht.diensten,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kon niet printen: $e')));
      }
    } finally {
      if (mounted) setState(() => _bezigMetPrinten = false);
    }
  }

  /// F3: tik op een bestaande shift (van wie dan ook) om ze te corrigeren
  /// of te verwijderen.
  Future<void> _bewerk(Dienst dienst) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DienstBewerkenScreen(dienst: dienst)),
    );
    _herlaad();
  }

  /// F3: iets toevoegen voor een gezinslid naar keuze.
  Future<void> _toevoegen(List<Gebruiker> gezinsleden) async {
    final voor = await showModalBottomSheet<Gebruiker>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Voor wie?'),
            ),
            for (final g in gezinsleden)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(g.naam),
                onTap: () => Navigator.of(context).pop(g),
              ),
          ],
        ),
      ),
    );
    if (voor == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DienstToevoegenScreen(
          profiel: widget.profiel,
          voorGebruiker: voor,
          initieleDatum: DateTime(_maandStart.year, _maandStart.month),
        ),
      ),
    );
    _herlaad();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gezamenlijk overzicht'),
        actions: [
          IconButton(
            icon: _bezigMetPrinten
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            tooltip: 'Printen',
            onPressed: _bezigMetPrinten ? null : _printen,
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<_Overzicht>(
        future: _overzicht,
        builder: (context, snapshot) {
          final leden = snapshot.data?.gebruikers ?? const <Gebruiker>[];
          if (leden.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _toevoegen(leden),
            icon: const Icon(Icons.add),
            label: const Text('Toevoegen'),
          );
        },
      ),
      // SafeArea: zonder dit overlapt de gebaren-navigatiebalk op sommige
      // Android-toestellen de onderkant van de lijst.
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppKleuren.bosgroenDonker,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    tooltip: 'Vorige maand',
                    onPressed: () => _wisselMaand(-1),
                  ),
                  Text(
                    DateFormat.yMMMM('nl_BE').format(_maandStart),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    tooltip: 'Volgende maand',
                    onPressed: () => _wisselMaand(1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<_Overzicht>(
                future: _overzicht,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Kon het overzicht niet laden: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    );
                  }

                  final overzicht = snapshot.data!;
                  if (overzicht.gebruikers.isEmpty) {
                    return const Center(child: Text('Nog geen gezinsleden.'));
                  }

                  final kaarten = _dagKaarten(overzicht);
                  if (kaarten.isEmpty) {
                    return const Center(
                      child: Text('Niks gepland deze maand.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: kaarten.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => kaarten[i],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bouwt 1 kaart per dag die effectief iets bevat (lege dagen worden
  /// overgeslagen i.p.v. als lege rij getoond - een tabel met 1 kolom per
  /// persoon paste niet netjes op een telefoonscherm, dit leest een pak
  /// duidelijker op mobiel).
  List<Widget> _dagKaarten(_Overzicht overzicht) {
    final kaarten = <Widget>[];
    for (var dagNr = 1; dagNr <= _maandEinde.day; dagNr++) {
      final dag = DateTime(_maandStart.year, _maandStart.month, dagNr);
      final dagIso = naarIsoDatum(dag);
      final regels = <(String naam, Dienst dienst)>[
        for (final gebruiker in overzicht.gebruikers)
          for (final dienst in overzicht.diensten.where(
            (d) => d.gebruikerId == gebruiker.uid && d.valtOpDatum(dagIso),
          ))
            (gebruiker.naam, dienst),
      ];
      if (regels.isEmpty) continue;
      kaarten.add(_DagKaart(dag: dag, regels: regels, onTik: _bewerk));
    }
    return kaarten;
  }
}

/// Eén dag uit het gezamenlijke overzicht: dag-label + 1 regel per
/// gezinslid met iets die dag ("Naam · tijd (omschrijving)"). Tik een regel
/// aan om ze te bewerken (F3).
class _DagKaart extends StatelessWidget {
  const _DagKaart({
    required this.dag,
    required this.regels,
    required this.onTik,
  });

  final DateTime dag;
  final List<(String naam, Dienst dienst)> regels;
  final ValueChanged<Dienst> onTik;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 0, bottom: 4),
              child: Text(
                naarDagLabel(dag),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppKleuren.bosgroenDonker,
                ),
              ),
            ),
            for (final (naam, dienst) in regels)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onTik(dienst),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppKleuren.terracotta,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('$naam · ${dienst.naarTekst()}')),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Colors.black38,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Overzicht {
  const _Overzicht({required this.gebruikers, required this.diensten});

  final List<Gebruiker> gebruikers;
  final List<Dienst> diensten;
}
