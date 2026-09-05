import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../pdf_import/formaat_a_parser.dart';

/// Tijdelijk testscherm voor stap 4.1: een PDF kiezen en op het scherm
/// zien wat FormaatAParser eruit haalt, zonder dat het al ergens
/// opgeslagen wordt (dat komt in een latere stap). Nu enkel bruikbaar voor
/// Ryan zijn rooster - de naam staat hieronder nog hardcoded.
class PdfTestScreen extends StatefulWidget {
  const PdfTestScreen({super.key});

  @override
  State<PdfTestScreen> createState() => _PdfTestScreenState();
}

class _PdfTestScreenState extends State<PdfTestScreen> {
  bool _bezig = false;
  String? _fout;
  List<Dienst>? _diensten;

  Future<void> _kiesEnLeesPdf() async {
    final bestand = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (bestand == null) return; // gebruiker heeft geannuleerd

    final bytes = await bestand.readAsBytes();

    setState(() {
      _bezig = true;
      _fout = null;
      _diensten = null;
    });

    try {
      final parser = FormaatAParser(naamInRooster: 'Wyters, Ryan');
      final diensten = parser.parse(
        bytes,
        gebruikerId: 'test',
        gebruikerNaam: 'Ryan',
      );
      setState(() => _diensten = diensten);
    } catch (e) {
      setState(() => _fout = 'Kon de PDF niet verwerken: $e');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF-rooster testen (Formaat A)')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _bezig ? null : _kiesEnLeesPdf,
              icon: const Icon(Icons.upload_file),
              label: const Text('Kies PDF-bestand'),
            ),
            const SizedBox(height: 24),
            if (_bezig) const Center(child: CircularProgressIndicator()),
            if (_fout != null)
              Text(
                _fout!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_diensten != null) Expanded(child: _resultaatLijst(_diensten!)),
          ],
        ),
      ),
    );
  }

  Widget _resultaatLijst(List<Dienst> diensten) {
    if (diensten.isEmpty) {
      return const Text('Geen shiften gevonden.');
    }
    return ListView.builder(
      itemCount: diensten.length,
      itemBuilder: (context, i) {
        final d = diensten[i];
        return ListTile(
          leading: const Icon(Icons.calendar_today),
          title: Text(d.datum),
          subtitle: Text('${d.startTijd} - ${d.eindTijd}'),
        );
      },
    );
  }
}
