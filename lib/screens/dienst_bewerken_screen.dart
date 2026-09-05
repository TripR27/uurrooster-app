import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../services/dienst_service.dart';
import '../util/datum_util.dart';

/// Scherm om één bestaande dienst te corrigeren of te verwijderen - nodig
/// omdat een PDF-import wel eens verkeerd kan uitpakken, en sowieso
/// omdat de app dit altijd moet toelaten (zie PROJECT_SPEC.md, sectie 1).
///
/// De datum is hier bewust nooit aanpasbaar (enkel uur + omschrijving) - een
/// PDF-import krijgt een document-id gebaseerd op zijn datum (zie
/// DienstService.slaPdfImportOp), dus die zou bij een gewijzigde datum een
/// verweesd/verkeerd document achterlaten; voor consistentie geldt dat nu
/// voor élke dienst hier, ook een handmatige. Wil je een shift op een andere
/// dag, verwijder 'm dan en voeg 'm opnieuw toe via "Toevoegen".
class DienstBewerkenScreen extends StatefulWidget {
  const DienstBewerkenScreen({super.key, required this.dienst});

  final Dienst dienst;

  @override
  State<DienstBewerkenScreen> createState() => _DienstBewerkenScreenState();
}

class _DienstBewerkenScreenState extends State<DienstBewerkenScreen> {
  late TimeOfDay _startTijd;
  late TimeOfDay _eindTijd;
  late final TextEditingController _omschrijvingController;

  bool _bezig = false;
  String? _fout;

  @override
  void initState() {
    super.initState();
    _startTijd = _naarTimeOfDay(widget.dienst.startTijd);
    _eindTijd = _naarTimeOfDay(widget.dienst.eindTijd);
    _omschrijvingController = TextEditingController(
      text: widget.dienst.omschrijving,
    );
  }

  @override
  void dispose() {
    _omschrijvingController.dispose();
    super.dispose();
  }

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

  Future<void> _opslaan() async {
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
          startTijd: _naarTijdString(_startTijd),
          eindTijd: _naarTijdString(_eindTijd),
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
        title: const Text('Shift verwijderen?'),
        content: Text(
          '${naarWeergaveDatum(widget.dienst.datum)}, '
          '${widget.dienst.startTijd} - ${widget.dienst.eindTijd} wordt '
          'verwijderd.',
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Datum'),
              subtitle: Text(naarWeergaveDatum(widget.dienst.datum)),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Van'),
              subtitle: Text(_naarTijdString(_startTijd)),
              trailing: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: _bezig ? null : () => _kiesTijd(isStart: true),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tot'),
              subtitle: Text(_naarTijdString(_eindTijd)),
              trailing: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: _bezig ? null : () => _kiesTijd(isStart: false),
              ),
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
    );
  }
}
