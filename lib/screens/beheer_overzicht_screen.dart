import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../print/overzicht_html.dart';
import '../print/printen.dart';
import '../services/dienst_service.dart';
import '../services/gebruiker_service.dart';
import '../theme.dart';
import '../util/datum_util.dart';

/// Gezamenlijk overzicht van alle gezinsleden, enkel voor de beheerder (zie
/// PROJECT_SPEC.md sectie 2 en 8) - een tabel met 1 kolom per persoon en 1
/// rij per dag van de gekozen maand, met een knop om dat rechtstreeks af te
/// drukken (sectie 9, zie `_printen` hieronder).
class BeheerOverzichtScreen extends StatefulWidget {
  const BeheerOverzichtScreen({super.key});

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

  void _wisselMaand(int aantalMaanden) {
    setState(() {
      _maandStart = DateTime(
        _maandStart.year,
        _maandStart.month + aantalMaanden,
      );
      _overzicht = _laadOverzicht();
    });
  }

  /// Bouwt de HTML van de huidig geladen maand (zie
  /// `lib/print/overzicht_html.dart`) en stuurt die rechtstreeks naar de
  /// systeem-printdialoog (`lib/print/printen.dart`) - geen tussenstap via
  /// opslaan/downloaden.
  Future<void> _printen() async {
    setState(() => _bezigMetPrinten = true);
    try {
      final overzicht = await _overzicht;
      final html = bouwOverzichtHtml(
        maandStart: _maandStart,
        gebruikers: overzicht.gebruikers,
        diensten: overzicht.diensten,
      );
      printHtml(html);
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
      body: Column(
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

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppKleuren.bosgroen.withValues(alpha: 0.1),
                      ),
                      columns: [
                        const DataColumn(label: Text('Dag')),
                        for (final gebruiker in overzicht.gebruikers)
                          DataColumn(label: Text(gebruiker.naam)),
                      ],
                      rows: [
                        for (var dagNr = 1; dagNr <= _maandEinde.day; dagNr++)
                          _dagRij(
                            dag: DateTime(
                              _maandStart.year,
                              _maandStart.month,
                              dagNr,
                            ),
                            gebruikers: overzicht.gebruikers,
                            diensten: overzicht.diensten,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DataRow _dagRij({
    required DateTime dag,
    required List<Gebruiker> gebruikers,
    required List<Dienst> diensten,
  }) {
    final dagIso = naarIsoDatum(dag);
    return DataRow(
      cells: [
        DataCell(Text(naarDagLabel(dag))),
        for (final gebruiker in gebruikers)
          DataCell(
            _CelInhoud(
              diensten: diensten
                  .where(
                    (d) => d.gebruikerId == gebruiker.uid && d.datum == dagIso,
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _CelInhoud extends StatelessWidget {
  const _CelInhoud({required this.diensten});

  final List<Dienst> diensten;

  @override
  Widget build(BuildContext context) {
    if (diensten.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.black38));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final dienst in diensten)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(dienst.naarTekst(scheidingVoorOmschrijving: '\n')),
          ),
      ],
    );
  }
}

class _Overzicht {
  const _Overzicht({required this.gebruikers, required this.diensten});

  final List<Gebruiker> gebruikers;
  final List<Dienst> diensten;
}
