import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../services/dienst_service.dart';

/// Scherm om het eigen PDF-rooster te uploaden: kiest het juiste
/// RoosterParser-formaat automatisch op basis van het profiel (zie
/// Gebruiker.maakParser()), toont een voorbeeld van wat eruit gehaald
/// wordt, en slaat dat pas op na bevestiging.
class PdfUploadScreen extends StatefulWidget {
  const PdfUploadScreen({super.key, required this.profiel});

  final Gebruiker profiel;

  @override
  State<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends State<PdfUploadScreen> {
  bool _bezig = false;
  String? _fout;
  List<Dienst>? _voorbeeld;
  bool _opgeslagen = false;

  Future<void> _kiesEnLeesPdf() async {
    final bestand = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (bestand == null) return; // gebruiker heeft geannuleerd

    final parser = widget.profiel.maakParser();
    if (parser == null) return; // knop staat dan sowieso uit, zie build()

    final bytes = await bestand.readAsBytes();

    setState(() {
      _bezig = true;
      _fout = null;
      _voorbeeld = null;
      _opgeslagen = false;
    });

    try {
      final diensten = parser.parse(
        bytes,
        gebruikerId: widget.profiel.uid,
        gebruikerNaam: widget.profiel.naam,
      );
      setState(() => _voorbeeld = diensten);
    } catch (e) {
      setState(() => _fout = 'Kon de PDF niet verwerken: $e');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  Future<void> _opslaan() async {
    final voorbeeld = _voorbeeld;
    if (voorbeeld == null) return;

    setState(() {
      _bezig = true;
      _fout = null;
    });
    try {
      await DienstService.slaPdfImportOp(voorbeeld);
      setState(() => _opgeslagen = true);
    } catch (e) {
      setState(() => _fout = 'Kon niet opslaan: $e');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parser = widget.profiel.maakParser();

    return Scaffold(
      appBar: AppBar(title: const Text('PDF-rooster uploaden')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (parser == null)
              const Text(
                'Voor dit account is nog geen PDF-formaat ingesteld. Vraag Ryjeaun mar!',
              )
            else
              FilledButton.icon(
                onPressed: _bezig ? null : _kiesEnLeesPdf,
                icon: const Icon(Icons.upload_file),
                label: const Text('Kies PDF-bestand'),
              ),
            const SizedBox(height: 16),
            // Enkel tonen tijdens het inlezen van de PDF: zodra er een
            // voorbeeld staat, toont de opslaan-knop zelf een laadcirkel.
            if (_bezig && _voorbeeld == null)
              const Center(child: CircularProgressIndicator()),
            if (_fout != null)
              Text(
                _fout!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_voorbeeld != null) ...[
              Text(
                '${_voorbeeld!.length} shiften gevonden:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Expanded(child: _dienstenLijst(_voorbeeld!)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _bezig || _opgeslagen ? null : _opslaan,
                child: _bezig
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_opgeslagen ? 'Opgeslagen' : 'Opslaan'),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text('Al opgeslagen:'),
              Expanded(child: _alOpgeslagenLijst()),
            ],
          ],
        ),
      ),
    );
  }

  /// Toont wat er voor dit account al opgeslagen staat - vooral handig om
  /// meteen te zien of een upload effectief goed wegschrijft.
  Widget _alOpgeslagenLijst() {
    return StreamBuilder<List<Dienst>>(
      stream: DienstService.eigenDiensten(widget.profiel.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text(
            'Kon niet laden: ${snapshot.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        return _dienstenLijst(snapshot.data ?? []);
      },
    );
  }

  Widget _dienstenLijst(List<Dienst> diensten) {
    if (diensten.isEmpty) {
      return const Text('Geen shiften gevonden.');
    }
    return ListView.builder(
      itemCount: diensten.length,
      itemBuilder: (context, i) {
        final d = diensten[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.calendar_today),
          title: Text(_naarWeergaveDatum(d.datum)),
          subtitle: Text(
            d.omschrijving.isEmpty
                ? '${d.startTijd} - ${d.eindTijd}'
                : '${d.startTijd} - ${d.eindTijd} (${d.omschrijving})',
          ),
        );
      },
    );
  }

  /// Zet het opgeslagen ISO-formaat ("2026-07-04") om naar "04-07-2026"
  /// voor op het scherm - de ISO-tekst zelf blijft intern gebruikt voor
  /// opslag/sortering (zie models/dienst.dart).
  String _naarWeergaveDatum(String isoDatum) {
    final delen = isoDatum.split('-');
    return '${delen[2]}-${delen[1]}-${delen[0]}';
  }
}
