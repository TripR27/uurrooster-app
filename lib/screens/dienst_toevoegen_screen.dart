import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../services/dienst_service.dart';
import '../widgets/dienst_formulier.dart';

/// Scherm om zelf iets toe te voegen zonder PDF - dat is niet altijd een
/// werkshift, ook een privé-afspraak of een vakantie op het gezamenlijke
/// rooster hoort hier (zie PROJECT_SPEC.md §1 en §4). Krijgt altijd
/// `bron: handmatig` en dus een automatisch gegenereerd document-id (zie
/// DienstService.aanmaken).
///
/// Het formulier zelf (datum/reeks + uren/hele dag + omschrijving) zit in
/// het gedeelde [DienstFormulier], zodat dit scherm en Bewerken er niet
/// elk een eigen versie van bijhouden.
class DienstToevoegenScreen extends StatefulWidget {
  const DienstToevoegenScreen({
    super.key,
    required this.profiel,
    this.voorGebruiker,
    this.initieleDatum,
  });

  /// De ingelogde gebruiker.
  final Gebruiker profiel;

  /// Voor wie de dienst aangemaakt wordt, als dat iemand anders is dan de
  /// ingelogde gebruiker - enkel de beheerder kan dit, vanuit het
  /// gezamenlijke overzicht (F3). `null` = voor jezelf.
  final Gebruiker? voorGebruiker;

  /// Datum waarmee het formulier opent - bv. de dag die net aangetikt werd
  /// in de kalenderweergave. Standaard vandaag als er niks meegegeven wordt.
  final DateTime? initieleDatum;

  @override
  State<DienstToevoegenScreen> createState() => _DienstToevoegenScreenState();
}

class _DienstToevoegenScreenState extends State<DienstToevoegenScreen> {
  final _formKey = GlobalKey<DienstFormulierState>();

  bool _bezig = false;
  String? _fout;

  Gebruiker get _doelgebruiker => widget.voorGebruiker ?? widget.profiel;

  Future<void> _opslaan() async {
    final concept = _formKey.currentState!.lees();
    setState(() {
      _bezig = true;
      _fout = null;
    });
    try {
      await DienstService.aanmaken(
        Dienst(
          gebruikerId: _doelgebruiker.uid,
          gebruikerNaam: _doelgebruiker.naam,
          datum: concept.datum,
          eindDatum: concept.eindDatum,
          startTijd: concept.startTijd,
          eindTijd: concept.eindTijd,
          heleDag: concept.heleDag,
          omschrijving: concept.omschrijving,
          bron: DienstBron.handmatig,
          aangemaaktOp: DateTime.now(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _fout = 'Kon niet opslaan: $e');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.voorGebruiker == null
              ? 'Toevoegen'
              : 'Toevoegen voor ${widget.voorGebruiker!.naam}',
        ),
      ),
      // SafeArea + SingleChildScrollView: zonder dit schuift het toetsenbord
      // de onderste velden en de knop uit beeld i.p.v. dat je ernaartoe kan
      // scrollen, en op sommige Android-toestellen overlapt de
      // gebaren-navigatiebalk anders de onderkant van het scherm.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DienstFormulier(
                key: _formKey,
                initieleDatum: widget.initieleDatum,
                enabled: !_bezig,
              ),
              const SizedBox(height: 28),
              if (_fout != null) ...[
                Text(
                  _fout!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _bezig ? null : _opslaan,
                child: _bezig
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Toevoegen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
