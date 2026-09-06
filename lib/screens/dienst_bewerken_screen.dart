import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../services/dienst_service.dart';
import '../util/datum_util.dart';

/// Scherm om één bestaande dienst te corrigeren of te verwijderen - nodig
/// omdat een PDF-import wel eens verkeerd kan uitpakken, en sowieso omdat de
/// app dit altijd moet toelaten (zie PROJECT_SPEC.md, §1).
///
/// De **begindatum** is hier bewust nooit aanpasbaar - een PDF-import krijgt
/// een document-id gebaseerd op zijn datum (zie DienstService.slaPdfImportOp),
/// dus die zou bij een gewijzigde datum een verweesd document achterlaten;
/// voor consistentie geldt dat voor élke dienst hier. Wil je iets op een
/// andere begindag, verwijder het dan en voeg het opnieuw toe via
/// "Toevoegen". De einddatum van een meerdaagse periode (F2) mag hier wél
/// aangepast worden.
class DienstBewerkenScreen extends StatefulWidget {
  const DienstBewerkenScreen({super.key, required this.dienst});

  final Dienst dienst;

  @override
  State<DienstBewerkenScreen> createState() => _DienstBewerkenScreenState();
}

class _DienstBewerkenScreenState extends State<DienstBewerkenScreen> {
  late TimeOfDay _startTijd;
  late TimeOfDay _eindTijd;
  late DateTime _eindDatum;

  /// Aangevinkt = enkel een startuur, geen einduur (zie PROJECT_SPEC.md F1).
  late bool _alleenStart;

  /// Aangevinkt = de hele dag, geen uren (F2).
  late bool _heleDag;

  /// Aangevinkt = een periode van meerdere dagen (F2).
  late bool _meerdereDagen;

  late final TextEditingController _omschrijvingController;

  bool _bezig = false;
  String? _fout;

  @override
  void initState() {
    super.initState();
    _heleDag = widget.dienst.heleDag;
    _alleenStart = !_heleDag && widget.dienst.eindTijd == null;

    final start = widget.dienst.startTijd;
    _startTijd = start != null
        ? _naarTimeOfDay(start)
        : const TimeOfDay(hour: 9, minute: 0);
    // Als er nog geen einduur was: een uur na de start als handig startpunt
    // voor wanneer de gebruiker "Alleen een startuur"/"Hele dag" uitvinkt.
    _eindTijd = widget.dienst.eindTijd != null
        ? _naarTimeOfDay(widget.dienst.eindTijd!)
        : _startTijd.replacing(hour: (_startTijd.hour + 1) % 24);

    _meerdereDagen = widget.dienst.isMeerdaags;
    _eindDatum = vanIsoDatum(widget.dienst.eindDatum ?? widget.dienst.datum);

    _omschrijvingController = TextEditingController(
      text: widget.dienst.omschrijving,
    );
  }

  @override
  void dispose() {
    _omschrijvingController.dispose();
    super.dispose();
  }

  DateTime get _beginDatum => vanIsoDatum(widget.dienst.datum);

  TimeOfDay _naarTimeOfDay(String hhmm) {
    final delen = hhmm.split(':');
    return TimeOfDay(hour: int.parse(delen[0]), minute: int.parse(delen[1]));
  }

  String _naarTijdString(TimeOfDay tijd) =>
      '${tijd.hour.toString().padLeft(2, '0')}:${tijd.minute.toString().padLeft(2, '0')}';

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

  Future<void> _kiesEindDatum() async {
    final gekozen = await showDatePicker(
      context: context,
      initialDate: _eindDatum.isBefore(_beginDatum) ? _beginDatum : _eindDatum,
      firstDate: _beginDatum,
      lastDate: DateTime(_beginDatum.year + 2),
    );
    if (gekozen != null) setState(() => _eindDatum = gekozen);
  }

  Future<void> _opslaan() async {
    if (_meerdereDagen && _eindDatum.isBefore(_beginDatum)) {
      setState(() => _fout = 'De einddatum ligt vóór de begindatum.');
      return;
    }
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
          datum: widget.dienst.datum,
          eindDatum: _meerdereDagen ? naarIsoDatum(_eindDatum) : null,
          startTijd: _heleDag ? null : _naarTijdString(_startTijd),
          eindTijd: (_heleDag || _alleenStart)
              ? null
              : _naarTijdString(_eindTijd),
          heleDag: _heleDag,
          omschrijving: _omschrijvingController.text.trim(),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_meerdereDagen ? 'Van' : 'Datum'),
                subtitle: Text(naarWeergaveDatum(widget.dienst.datum)),
              ),
              if (_meerdereDagen)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tot en met'),
                  subtitle: Text(naarWeergaveDatum(naarIsoDatum(_eindDatum))),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    onPressed: _bezig ? null : _kiesEindDatum,
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
                        if (_meerdereDagen &&
                            _eindDatum.isBefore(_beginDatum)) {
                          _eindDatum = _beginDatum;
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
                decoration: const InputDecoration(labelText: 'Omschrijving'),
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
                    : const Text('Opslaan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
