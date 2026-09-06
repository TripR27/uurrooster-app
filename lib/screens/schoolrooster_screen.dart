import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../school/schoolrooster_service.dart';
import '../services/dienst_service.dart';
import '../theme.dart';
import '../widgets/dienst_tile.dart';

/// Scherm om Ryans schoolrooster op te halen uit WebUntis (F4). Kies een
/// maand, "Ophalen" toont een voorbeeld van je schooldagen (vroegste begin
/// → laatste einde), "Opslaan" zet ze op je shiften met `bron:
/// schoolrooster`. Opnieuw ophalen voor dezelfde maand overschrijft.
///
/// Werkt enkel in de Android-app: de webversie mag `ap.webuntis.com` niet
/// rechtstreeks aanroepen (browserbeveiliging / CORS).
class SchoolroosterScreen extends StatefulWidget {
  const SchoolroosterScreen({super.key, required this.profiel});

  final Gebruiker profiel;

  @override
  State<SchoolroosterScreen> createState() => _SchoolroosterScreenState();
}

class _SchoolroosterScreenState extends State<SchoolroosterScreen> {
  late DateTime _maand;
  bool _bezig = false;
  String? _fout;
  List<Dienst>? _voorbeeld;

  @override
  void initState() {
    super.initState();
    final nu = DateTime.now();
    _maand = DateTime(nu.year, nu.month);
  }

  void _wisselMaand(int delta) {
    setState(() {
      _maand = DateTime(_maand.year, _maand.month + delta);
      _voorbeeld = null;
      _fout = null;
    });
  }

  Future<void> _ophalen() async {
    setState(() {
      _bezig = true;
      _fout = null;
      _voorbeeld = null;
    });
    try {
      final dagen = await SchoolroosterService.haalMaand(
        klasId: widget.profiel.webuntisKlasId!,
        minorVak: widget.profiel.webuntisMinor!,
        jaar: _maand.year,
        maand: _maand.month,
      );
      final diensten = [
        for (final dag in dagen)
          schooldagNaarDienst(
            dag,
            gebruikerId: widget.profiel.uid,
            gebruikerNaam: widget.profiel.naam,
          ),
      ];
      setState(() => _voorbeeld = diensten);
    } catch (e) {
      setState(() => _fout = '$e');
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
      await DienstService.slaSchoolroosterOp(
        gebruikerId: widget.profiel.uid,
        diensten: voorbeeld,
        jaar: _maand.year,
        maand: _maand.month,
      );
      if (mounted) Navigator.of(context).pop(voorbeeld.length);
    } catch (e) {
      setState(() => _fout = 'Kon niet opslaan: $e');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schoolrooster')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppKleuren.bosgroenDonker,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    color: AppKleuren.terracotta,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Haal per maand op van wanneer tot wanneer je op '
                      'school bent',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: kIsWeb ? _webUitleg(context) : _inhoud(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webUitleg(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Het schoolrooster ophalen werkt enkel in de Android-app - de '
          'webversie mag WebUntis niet rechtstreeks aanspreken.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _inhoud(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Vorige maand',
                onPressed: _bezig ? null : () => _wisselMaand(-1),
              ),
              Text(
                DateFormat.yMMMM('nl_BE').format(_maand),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Volgende maand',
                onPressed: _bezig ? null : () => _wisselMaand(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _bezig ? null : _ophalen,
            icon: const Icon(Icons.download),
            label: const Text('Rooster ophalen'),
          ),
          const SizedBox(height: 16),
          if (_bezig && _voorbeeld == null)
            const Center(child: CircularProgressIndicator()),
          if (_fout != null)
            Text(
              _fout!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_voorbeeld != null) ...[
            Text(
              _voorbeeld!.isEmpty
                  ? 'Geen schooldagen gevonden voor deze maand.'
                  : '${_voorbeeld!.length} schooldagen gevonden:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _voorbeeld!.length,
                itemBuilder: (context, i) =>
                    DienstTile(dienst: _voorbeeld![i]),
              ),
            ),
            if (_voorbeeld!.isNotEmpty) ...[
              const SizedBox(height: 12),
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
        ],
      ),
    );
  }
}
