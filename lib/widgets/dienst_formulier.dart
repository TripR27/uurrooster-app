import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dienst.dart';
import '../theme.dart';
import '../util/datum_util.dart';

/// De verzameling waarden die [DienstFormulier] oplevert via
/// [DienstFormulierState.lees].
class DienstConcept {
  const DienstConcept({
    required this.datum,
    required this.eindDatum,
    required this.startTijd,
    required this.eindTijd,
    required this.heleDag,
    required this.omschrijving,
  });

  final String datum; // ISO
  final String? eindDatum; // ISO, null = eendaags
  final String? startTijd; // "HH:MM", null bij heleDag
  final String? eindTijd; // "HH:MM", null bij heleDag of "alleen startuur"
  final bool heleDag;
  final String omschrijving;
}

/// Gedeeld formulier voor "iets toevoegen" en "iets bewerken": één dag of
/// een reeks dagen (F2), met of zonder uren (F1/F2), plus een omschrijving.
///
/// De begindatum kan vergrendeld worden ([datumVast], gebruikt door
/// Bewerken - zie de document-id-afspraak in PROJECT_SPEC.md §4). De
/// einddatum van een meerdaagse periode blijft dan wél aanpasbaar.
///
/// Lees de ingevulde waarden op via een `GlobalKey<DienstFormulierState>`
/// en `.currentState!.lees()`.
class DienstFormulier extends StatefulWidget {
  const DienstFormulier({
    super.key,
    this.bestaande,
    this.initieleDatum,
    this.datumVast = false,
    this.enabled = true,
  });

  /// De dienst die bewerkt wordt, of `null` bij een nieuwe.
  final Dienst? bestaande;

  /// Startdatum waarmee een nieuw formulier opent (bv. de dag die net in de
  /// kalender aangetikt werd). Genegeerd als [bestaande] gezet is.
  final DateTime? initieleDatum;

  /// Begindatum niet aanpasbaar (Bewerken).
  final bool datumVast;

  final bool enabled;

  @override
  State<DienstFormulier> createState() => DienstFormulierState();
}

class DienstFormulierState extends State<DienstFormulier> {
  late DateTime _datum;
  DateTime? _eindDatum; // null = eendaags
  late TimeOfDay _startTijd;
  TimeOfDay? _eindTijd; // null = "alleen een startuur"
  late bool _heleDag;
  late final TextEditingController _omschrijving;

  static final _langeDatum = DateFormat('EEEE d MMMM yyyy', 'nl_BE');
  static final _korteDatum = DateFormat('d MMM', 'nl_BE');
  static final _korteDatumJaar = DateFormat('d MMM yyyy', 'nl_BE');

  @override
  void initState() {
    super.initState();
    final b = widget.bestaande;

    final ruweDatum = b != null
        ? vanIsoDatum(b.datum)
        : (widget.initieleDatum ?? DateTime.now());
    _datum = DateTime(ruweDatum.year, ruweDatum.month, ruweDatum.day);
    _eindDatum = b?.eindDatum != null ? vanIsoDatum(b!.eindDatum!) : null;

    _heleDag = b?.heleDag ?? false;

    final nu = TimeOfDay.now();
    _startTijd = b?.startTijd != null ? _parseTijd(b!.startTijd!) : nu;
    if (b == null) {
      _eindTijd = nu.replacing(hour: (nu.hour + 1) % 24);
    } else {
      // Bestaande dienst: einduur tonen zoals opgeslagen (null = alleen
      // een startuur, of hele dag).
      _eindTijd = b.eindTijd != null ? _parseTijd(b.eindTijd!) : null;
    }

    _omschrijving = TextEditingController(text: b?.omschrijving ?? '');
  }

  @override
  void dispose() {
    _omschrijving.dispose();
    super.dispose();
  }

  TimeOfDay _parseTijd(String hhmm) {
    final d = hhmm.split(':');
    return TimeOfDay(hour: int.parse(d[0]), minute: int.parse(d[1]));
  }

  String _tijdString(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay get _eindTijdOfStandaard =>
      _eindTijd ?? _startTijd.replacing(hour: (_startTijd.hour + 1) % 24);

  /// De ingevulde waarden. De reeks-/tijdkiezers garanderen zelf al een
  /// geldige volgorde, dus dit lukt altijd.
  DienstConcept lees() {
    final meerdaags = _eindDatum != null;
    return DienstConcept(
      datum: naarIsoDatum(_datum),
      eindDatum: meerdaags ? naarIsoDatum(_eindDatum!) : null,
      startTijd: _heleDag ? null : _tijdString(_startTijd),
      eindTijd: (_heleDag || _eindTijd == null)
          ? null
          : _tijdString(_eindTijd!),
      heleDag: _heleDag,
      omschrijving: _omschrijving.text.trim(),
    );
  }

  // --- Kiezers -------------------------------------------------------------

  Future<void> _kiesDatumOfReeks() async {
    if (!widget.enabled) return;

    // Meerdaags + vrije begindatum: één kalender waarin je begin- én
    // einddatum na elkaar aanduidt.
    if (_eindDatum != null && !widget.datumVast) {
      final reeks = await showDateRangePicker(
        context: context,
        initialDateRange: DateTimeRange(start: _datum, end: _eindDatum!),
        firstDate: DateTime(_datum.year - 2),
        lastDate: DateTime(_datum.year + 3),
        helpText: 'Kies de eerste en laatste dag',
        saveText: 'Klaar',
      );
      if (reeks != null) {
        setState(() {
          _datum = DateTime(
            reeks.start.year,
            reeks.start.month,
            reeks.start.day,
          );
          _eindDatum = DateTime(reeks.end.year, reeks.end.month, reeks.end.day);
        });
      }
      return;
    }

    // Meerdaags maar begindatum vast (Bewerken): enkel de einddatum kiezen.
    if (_eindDatum != null && widget.datumVast) {
      final gekozen = await showDatePicker(
        context: context,
        initialDate: _eindDatum!,
        firstDate: _datum,
        lastDate: DateTime(_datum.year + 3),
        helpText: 'Kies de laatste dag',
      );
      if (gekozen != null) {
        setState(
          () => _eindDatum = DateTime(
            gekozen.year,
            gekozen.month,
            gekozen.day,
          ),
        );
      }
      return;
    }

    // Eendaags.
    if (widget.datumVast) return;
    final gekozen = await showDatePicker(
      context: context,
      initialDate: _datum,
      firstDate: DateTime(_datum.year - 2),
      lastDate: DateTime(_datum.year + 3),
    );
    if (gekozen != null) {
      setState(
        () => _datum = DateTime(gekozen.year, gekozen.month, gekozen.day),
      );
    }
  }

  Future<void> _zetMeerdereDagen(bool aan) async {
    if (!aan) {
      setState(() => _eindDatum = null);
      return;
    }
    setState(() => _eindDatum = _datum);
    // Meteen de kalender openen zodat je niet nog een extra tik nodig hebt.
    await _kiesDatumOfReeks();
    // Niks gekozen? Dan blijft het een reeks van één dag - prima, de
    // gebruiker kan alsnog op het veld tikken.
  }

  Future<void> _kiesTijd({required bool isStart}) async {
    if (!widget.enabled) return;
    final gekozen = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTijd : _eindTijdOfStandaard,
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

  // --- Opbouw ------------------------------------------------------------

  String get _datumTekst {
    if (_eindDatum == null) return _langeDatum.format(_datum);
    return '${_korteDatum.format(_datum)}  →  ${_korteDatumJaar.format(_eindDatum!)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Met uren'),
              icon: Icon(Icons.schedule),
            ),
            ButtonSegment(
              value: true,
              label: Text('Hele dag'),
              icon: Icon(Icons.wb_sunny_outlined),
            ),
          ],
          selected: {_heleDag},
          onSelectionChanged: widget.enabled
              ? (keuze) => setState(() => _heleDag = keuze.first)
              : null,
          showSelectedIcon: false,
        ),
        const SizedBox(height: 24),

        _Label(_eindDatum == null ? 'Datum' : 'Van wanneer tot wanneer'),
        const SizedBox(height: 8),
        _TikVeld(
          icoon: Icons.calendar_month,
          tekst: _datumTekst,
          vergrendeld: widget.datumVast && _eindDatum == null,
          onTap: widget.enabled ? _kiesDatumOfReeks : null,
        ),
        const SizedBox(height: 4),
        _SchakelRij(
          label: 'Meerdere dagen',
          waarde: _eindDatum != null,
          onChanged: widget.enabled ? _zetMeerdereDagen : null,
        ),

        if (!_heleDag) ...[
          const SizedBox(height: 16),
          _Label('Uren'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TikVeld(
                  icoon: Icons.schedule,
                  bovenschrift: 'Van',
                  tekst: _tijdString(_startTijd),
                  onTap: widget.enabled
                      ? () => _kiesTijd(isStart: true)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _eindTijd == null
                    ? _TikVeld(
                        icoon: Icons.add,
                        tekst: 'Einduur',
                        gedempt: true,
                        onTap: widget.enabled
                            ? () => setState(
                                () => _eindTijd = _eindTijdOfStandaard,
                              )
                            : null,
                      )
                    : _TikVeld(
                        icoon: Icons.schedule,
                        bovenschrift: 'Tot',
                        tekst: _tijdString(_eindTijd!),
                        onWis: widget.enabled
                            ? () => setState(() => _eindTijd = null)
                            : null,
                        onTap: widget.enabled
                            ? () => _kiesTijd(isStart: false)
                            : null,
                      ),
              ),
            ],
          ),
          if (_eindTijd == null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Enkel een startuur - geen einduur bekend.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],

        const SizedBox(height: 20),
        _Label('Omschrijving'),
        const SizedBox(height: 8),
        TextField(
          controller: _omschrijving,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'bv. Werk, Tandarts, Vakantie, ...',
          ),
        ),
      ],
    );
  }
}

/// Klein kopje boven een veld.
class _Label extends StatelessWidget {
  const _Label(this.tekst);
  final String tekst;

  @override
  Widget build(BuildContext context) {
    return Text(
      tekst,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppKleuren.bosgroenDonker,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Een tikbaar veld dat eruitziet als een invoerveld: icoon links, tekst,
/// optioneel een klein kopje erboven en/of een wis-knop rechts.
class _TikVeld extends StatelessWidget {
  const _TikVeld({
    required this.icoon,
    required this.tekst,
    this.bovenschrift,
    this.onTap,
    this.onWis,
    this.vergrendeld = false,
    this.gedempt = false,
  });

  final IconData icoon;
  final String tekst;
  final String? bovenschrift;
  final VoidCallback? onTap;
  final VoidCallback? onWis;
  final bool vergrendeld;
  final bool gedempt;

  @override
  Widget build(BuildContext context) {
    final kleur = gedempt || vergrendeld
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : AppKleuren.inkt;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: vergrendeld ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppKleuren.bosgroen.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(icoon, size: 20, color: AppKleuren.bosgroen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (bovenschrift != null)
                      Text(
                        bovenschrift!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      tekst,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: kleur,
                        fontStyle: gedempt ? FontStyle.italic : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (vergrendeld)
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              if (onWis != null)
                InkWell(
                  onTap: onWis,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compacte schakelaar-rij ("Meerdere dagen").
class _SchakelRij extends StatelessWidget {
  const _SchakelRij({
    required this.label,
    required this.waarde,
    required this.onChanged,
  });

  final String label;
  final bool waarde;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: waarde,
      onChanged: onChanged,
    );
  }
}
