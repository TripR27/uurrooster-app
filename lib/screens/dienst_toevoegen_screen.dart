import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../services/dienst_service.dart';
import '../util/datum_util.dart';

/// Scherm om zelf iets toe te voegen zonder PDF - dat is niet altijd een
/// werkshift, ook een privé-afspraak of een vakantie op het gezamenlijke
/// rooster hoort hier (zie PROJECT_SPEC.md §1 en §4). Krijgt altijd
/// `bron: handmatig` en dus een automatisch gegenereerd document-id (zie
/// DienstService.aanmaken).
///
/// Een item kan een begin+einduur hebben, enkel een startuur (F1), de hele
/// dag duren of meerdere dagen beslaan (F2).
class DienstToevoegenScreen extends StatefulWidget {
  const DienstToevoegenScreen({
    super.key,
    required this.profiel,
    this.initieleDatum,
  });

  final Gebruiker profiel;

  /// Datum waarmee het formulier opent - bv. de dag die net aangetikt werd
  /// in de kalenderweergave. Standaard vandaag als er niks meegegeven wordt.
  final DateTime? initieleDatum;

  @override
  State<DienstToevoegenScreen> createState() => _DienstToevoegenScreenState();
}

class _DienstToevoegenScreenState extends State<DienstToevoegenScreen> {
  // Standaard "nu" resp. "over een uur" - gewoon een handig startpunt, de
  // gebruiker past dit meteen zelf aan via de tijdkiezers hieronder.
  late DateTime _datum;
  late DateTime _eindDatum;
  late TimeOfDay _startTijd;
  late TimeOfDay _eindTijd;

  /// Aangevinkt = enkel een startuur, geen einduur (bv. "afspraak om 15u,
  /// geen idee tot wanneer" - zie PROJECT_SPEC.md F1).
  bool _alleenStart = false;

  /// Aangevinkt = de hele dag, geen uren (F2).
  bool _heleDag = false;

  /// Aangevinkt = een periode van meerdere dagen (F2).
  bool _meerdereDagen = false;

  final _omschrijvingController = TextEditingController();

  bool _bezig = false;
  String? _fout;

  @override
  void initState() {
    super.initState();
    final nu = TimeOfDay.now();
    _datum = widget.initieleDatum ?? DateTime.now();
    _eindDatum = _datum;
    _startTijd = nu;
    _eindTijd = nu.replacing(hour: (nu.hour + 1) % 24);
  }

  @override
  void dispose() {
    _omschrijvingController.dispose();
    super.dispose();
  }

  String _naarTijdString(TimeOfDay tijd) =>
      '${tijd.hour.toString().padLeft(2, '0')}:${tijd.minute.toString().padLeft(2, '0')}';

  Future<void> _kiesDatum({required bool isStart}) async {
    final huidige = isStart ? _datum : _eindDatum;
    final gekozen = await showDatePicker(
      context: context,
      initialDate: huidige,
      firstDate: DateTime(_datum.year - 1),
      lastDate: DateTime(_datum.year + 2),
    );
    if (gekozen == null) return;
    setState(() {
      if (isStart) {
        _datum = gekozen;
        // Einddatum nooit vóór de begindatum laten staan.
        if (_eindDatum.isBefore(_datum)) _eindDatum = _datum;
      } else {
        _eindDatum = gekozen;
      }
    });
  }

  Future<void> _kiesTijd({required bool isStart}) async {
    final gekozen = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTijd : _eindTijd,
    );
    if (gekozen == null) return;
    setState(() {
      if (isStart) {
        _startTijd = gekozen;
      } else {
        _eindTijd = gekozen;
      }
    });
  }

  Future<void> _opslaan() async {
    if (_meerdereDagen && _eindDatum.isBefore(_datum)) {
      setState(() => _fout = 'De einddatum ligt vóór de begindatum.');
      return;
    }
    setState(() {
      _bezig = true;
      _fout = null;
    });
    try {
      await DienstService.aanmaken(
        Dienst(
          gebruikerId: widget.profiel.uid,
          gebruikerNaam: widget.profiel.naam,
          datum: naarIsoDatum(_datum),
          eindDatum: _meerdereDagen ? naarIsoDatum(_eindDatum) : null,
          startTijd: _heleDag ? null : _naarTijdString(_startTijd),
          eindTijd: (_heleDag || _alleenStart)
              ? null
              : _naarTijdString(_eindTijd),
          heleDag: _heleDag,
          omschrijving: _omschrijvingController.text.trim(),
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
      appBar: AppBar(title: const Text('Toevoegen')),
      // SafeArea + SingleChildScrollView: zonder dit schuift het toetsenbord
      // de onderste velden en de knop uit beeld i.p.v. dat je ernaartoe kan
      // scrollen, en op sommige Android-toestellen overlapt de
      // gebaren-navigatiebalk anders de onderkant van het scherm.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_meerdereDagen ? 'Van' : 'Datum'),
                subtitle: Text(naarWeergaveDatum(naarIsoDatum(_datum))),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: _bezig ? null : () => _kiesDatum(isStart: true),
                ),
              ),
              if (_meerdereDagen)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tot en met'),
                  subtitle: Text(naarWeergaveDatum(naarIsoDatum(_eindDatum))),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    onPressed: _bezig ? null : () => _kiesDatum(isStart: false),
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Meerdere dagen'),
                subtitle: const Text('bv. een vakantie van 10 tot 15 sep'),
                value: _meerdereDagen,
                onChanged: _bezig
                    ? null
                    : (v) => setState(() {
                        _meerdereDagen = v ?? false;
                        if (_meerdereDagen && _eindDatum.isBefore(_datum)) {
                          _eindDatum = _datum;
                        }
                      }),
              ),
              const Divider(),
              if (!_heleDag) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Van'),
                  subtitle: Text(_naarTijdString(_startTijd)),
                  trailing: IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: _bezig ? null : () => _kiesTijd(isStart: true),
                  ),
                ),
                if (!_alleenStart)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tot'),
                    subtitle: Text(_naarTijdString(_eindTijd)),
                    trailing: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: _bezig
                          ? null
                          : () => _kiesTijd(isStart: false),
                    ),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alleen een startuur'),
                  subtitle: const Text('Geen einduur bekend'),
                  value: _alleenStart,
                  onChanged: _bezig
                      ? null
                      : (v) => setState(() => _alleenStart = v ?? false),
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hele dag'),
                subtitle: const Text('Geen begin-/einduur'),
                value: _heleDag,
                onChanged: _bezig
                    ? null
                    : (v) => setState(() => _heleDag = v ?? false),
              ),
              const Divider(),
              TextField(
                controller: _omschrijvingController,
                decoration: const InputDecoration(
                  labelText: 'Omschrijving',
                  hintText: 'bv. Tandarts, Vakantie, Privé-afspraak, ...',
                ),
              ),
              const SizedBox(height: 24),
              if (_fout != null)
                Text(
                  _fout!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
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
