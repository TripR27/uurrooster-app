import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../services/dienst_service.dart';
import '../util/datum_util.dart';
import '../widgets/dienst_formulier.dart';

/// Scherm om één bestaande dienst te corrigeren of te verwijderen - nodig
/// omdat een PDF-import wel eens verkeerd kan uitpakken, en sowieso omdat de
/// app dit altijd moet toelaten (zie PROJECT_SPEC.md, §1).
///
/// De **begindatum** is hier bewust niet aanpasbaar (`datumVast` op het
/// gedeelde [DienstFormulier]) - een PDF-import krijgt een document-id
/// gebaseerd op zijn datum (zie DienstService.slaPdfImportOp), dus die zou
/// bij een gewijzigde datum een verweesd document achterlaten; voor
/// consistentie geldt dat voor élke dienst hier. Wil je iets op een andere
/// begindag, verwijder het dan en voeg het opnieuw toe via "Toevoegen". De
/// einddatum van een meerdaagse periode (F2) mag hier wél aangepast worden.
class DienstBewerkenScreen extends StatefulWidget {
  const DienstBewerkenScreen({super.key, required this.dienst});

  final Dienst dienst;

  @override
  State<DienstBewerkenScreen> createState() => _DienstBewerkenScreenState();
}

class _DienstBewerkenScreenState extends State<DienstBewerkenScreen> {
  final _formKey = GlobalKey<DienstFormulierState>();

  bool _bezig = false;
  String? _fout;

  Future<void> _opslaan() async {
    final concept = _formKey.currentState!.lees();
    setState(() {
      _bezig = true;
      _fout = null;
    });
    try {
      await DienstService.bijwerken(
        Dienst(
          id: widget.dienst.id,
          gebruikerId: widget.dienst.gebruikerId,
          gebruikerNaam: widget.dienst.gebruikerNaam,
          datum: concept.datum,
          eindDatum: concept.eindDatum,
          startTijd: concept.startTijd,
          eindTijd: concept.eindTijd,
          heleDag: concept.heleDag,
          omschrijving: concept.omschrijving,
          bron: widget.dienst.bron,
          aangemaaktOp: widget.dienst.aangemaaktOp,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _fout = 'Kon niet opslaan: $e');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  Future<void> _verwijderen() async {
    final bevestigd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verwijderen?'),
        content: Text(
          '${naarWeergaveDatum(widget.dienst.datum)}, '
          '${widget.dienst.naarTekst()} wordt verwijderd.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (bevestigd != true) return;

    setState(() {
      _bezig = true;
      _fout = null;
    });
    try {
      await DienstService.verwijderen(widget.dienst.id!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _fout = 'Kon niet verwijderen: $e';
        _bezig = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bewerken'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Verwijderen',
            onPressed: _bezig ? null : _verwijderen,
          ),
        ],
      ),
      // SafeArea + SingleChildScrollView: zonder dit schuift het toetsenbord
      // (bv. bij het intikken van de omschrijving) de onderste velden en de
      // opslaan-knop gewoon uit beeld i.p.v. dat je ernaartoe kan scrollen,
      // en op sommige Android-toestellen overlapt de gebaren-navigatiebalk
      // anders de onderkant van het scherm.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DienstFormulier(
                key: _formKey,
                bestaande: widget.dienst,
                datumVast: true,
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
                    : const Text('Opslaan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
