import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../services/dienst_service.dart';
import '../theme.dart';
import '../widgets/dienst_tile.dart';

/// Scherm om het eigen PDF-rooster te uploaden: kiest het juiste
/// RoosterParser-formaat automatisch op basis van het profiel (zie
/// Gebruiker.maakParser()), toont een voorbeeld van wat eruit gehaald
/// wordt, en slaat dat pas op na bevestiging. Nadien terug te vinden (en
/// te corrigeren) op het overzichtscherm.
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

  /// Slaat op en gaat meteen terug naar het startscherm (i.p.v. hier een
  /// "opgeslagen"-tekst te tonen) - dat leest beter door. Geeft het aantal
  /// opgeslagen shiften mee als pop-resultaat, zodat het startscherm daar
  /// een bevestiging over kan tonen (zie HomeScreen._MenuKaart-onTap).
  Future<void> _opslaan() async {
    final voorbeeld = _voorbeeld;
    if (voorbeeld == null) return;

    setState(() {
      _bezig = true;
      _fout = null;
    });
    try {
      await DienstService.slaPdfImportOp(voorbeeld);
      if (mounted) Navigator.of(context).pop(voorbeeld.length);
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
      // SafeArea: zonder dit overlapt de gebaren-navigatiebalk op sommige
      // Android-toestellen de opslaan-knop onderaan.
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppKleuren.bosgroenDonker,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: AppKleuren.terracotta,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lees je werkrooster in en zet het meteen op je '
                      'shiften',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
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
                    // Enkel tonen tijdens het inlezen van de PDF: zodra er
                    // een voorbeeld staat, toont de opslaan-knop zelf een
                    // laadcirkel.
                    if (_bezig && _voorbeeld == null)
                      const Center(child: CircularProgressIndicator()),
                    if (_fout != null)
                      Text(
                        _fout!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (_voorbeeld != null) ...[
                      Text(
                        '${_voorbeeld!.length} shiften gevonden:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _voorbeeld!.length,
                          itemBuilder: (context, i) =>
                              DienstTile(dienst: _voorbeeld![i]),
                        ),
                      ),
                      const SizedBox(height: 16),
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
