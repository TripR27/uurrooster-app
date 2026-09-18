import 'package:flutter/material.dart';

import '../models/gebruiker.dart';
import '../services/gebruiker_service.dart';
import '../theme.dart';

/// Het "Beheer"-tabje, enkel bereikbaar voor de beheerder (zie
/// PROJECT_SPEC.md F7/F12): bovenaan een algemene "alle meldingen
/// ontvangen"-schakelaar voor de ingelogde beheerder zelf, daaronder een
/// lijst van alle gezinsleden met per rij een "Beheer"-knop. Die opent een
/// pop-up met alles wat voor die ene persoon instelbaar is: meldingen bij
/// een import (bulk) en bij handmatig toevoegen (single) elk apart aan/uit,
/// onzichtbaar maken voor anderen (F7/F8) en het gezamenlijke overzicht
/// voor die persoon zelf verbergen (F12).
class BeheerInstellingenScreen extends StatefulWidget {
  const BeheerInstellingenScreen({super.key, required this.profiel});

  /// De ingelogde beheerder - enkel gebruikt om te weten welke rij "jezelf"
  /// is voor de algemene meldingen-schakelaar.
  final Gebruiker profiel;

  @override
  State<BeheerInstellingenScreen> createState() =>
      _BeheerInstellingenScreenState();
}

class _BeheerInstellingenScreenState extends State<BeheerInstellingenScreen> {
  late Future<List<Gebruiker>> _laadFuture;
  // Aparte, rechtstreeks bijgewerkte lijst (i.p.v. _laadFuture zelf telkens
  // te vervangen) - anders zou elke toggle de FutureBuilder eventjes terug
  // naar "laden" sturen, en dus de scrollpositie van de lijst resetten.
  List<Gebruiker>? _lijst;

  @override
  void initState() {
    super.initState();
    _laadFuture = GebruikerService.alleGebruikers().then((lijst) {
      _sorteer(lijst);
      return _lijst = lijst;
    });
  }

  Future<void> _herlaad() async {
    final lijst = await GebruikerService.alleGebruikers();
    _sorteer(lijst);
    if (mounted) setState(() => _lijst = lijst);
  }

  /// Zichtbare gezinsleden eerst (op naam), onzichtbare (F7) onderaan (ook
  /// op naam) - zo blijft de lijst overzichtelijk en val je niet meteen op
  /// dat iemand onzichtbaar staat tussen de "normale" rijen door.
  void _sorteer(List<Gebruiker> lijst) {
    lijst.sort((a, b) {
      if (a.zichtbaarInOverzicht != b.zichtbaarInOverzicht) {
        return a.zichtbaarInOverzicht ? -1 : 1;
      }
      return a.naam.compareTo(b.naam);
    });
  }

  Future<void> _zetWilMeldingen(bool wil) async {
    setState(() {
      _lijst = [
        for (final g in _lijst!)
          if (g.uid == widget.profiel.uid) g.copyWith(wilMeldingen: wil) else g,
      ];
    });
    try {
      await GebruikerService.zetWilMeldingen(widget.profiel.uid, wil);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kon niet opslaan: $e')));
      await _herlaad();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beheer')),
      body: SafeArea(
        child: FutureBuilder<List<Gebruiker>>(
          future: _laadFuture,
          builder: (context, snapshot) {
            if (_lijst == null &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_lijst == null && snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Kon de gezinsleden niet laden: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              );
            }

            final gebruikers = _lijst!;
            final eigenProfiel = gebruikers.firstWhere(
              (g) => g.uid == widget.profiel.uid,
              orElse: () => widget.profiel,
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Sectietitel('Meldingen'),
                _Kaart(
                  child: SwitchListTile(
                    title: const Text('Alle meldingen ontvangen'),
                    subtitle: const Text(
                      'Zet uit om tijdelijk geen pushmeldingen te krijgen. '
                      'De instelling per gezinslid blijft dan gewoon staan '
                      'zoals ze stond, en komt terug in gebruik zodra je '
                      'dit weer aanzet.',
                    ),
                    value: eigenProfiel.wilMeldingen,
                    activeThumbColor: AppKleuren.bosgroen,
                    onChanged: _zetWilMeldingen,
                  ),
                ),

                const SizedBox(height: 20),
                _Sectietitel('Gezinsleden'),
                _Sectiehelp(
                  'Tik op "Beheer" om per gezinslid meldingen, '
                  'zichtbaarheid en het gezamenlijke overzicht in te '
                  'stellen.',
                ),
                for (final gebruiker in gebruikers) ...[
                  _GebruikerRij(
                    gebruiker: gebruiker,
                    onBeheer: () => _openBeheerDialoog(
                      gebruiker,
                      meldingenGeblokkeerd: !eigenProfiel.wilMeldingen,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openBeheerDialoog(
    Gebruiker gebruiker, {
    required bool meldingenGeblokkeerd,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _GebruikerBeheerDialoog(
        gebruiker: gebruiker,
        meldingenGeblokkeerd: meldingenGeblokkeerd,
        // De pop-up slaat elke wijziging zelf al op in Firestore; dit
        // spiegelt enkel diezelfde wijziging in de lokale lijst, zodat de
        // status-chips/gedempte achtergrond (F12) meteen bijwerken zonder
        // dat het hele scherm herladen moet worden - en zodat de pop-up bij
        // een volgende keer openen niet stiekem verouderde waarden toont.
        onGewijzigd: (wijzig) => setState(() {
          _lijst = [
            for (final g in _lijst!)
              if (g.uid == gebruiker.uid) wijzig(g) else g,
          ];
          // Herordenen: onzichtbaar togglen kan de plaats in de lijst
          // veranderen (onzichtbaar staat onderaan).
          _sorteer(_lijst!);
        }),
      ),
    );
  }
}

/// Pop-up met alle instellingen voor één gezinslid. Houdt een eigen, lokale
/// kopie van de 4 schakelaars bij (i.p.v. rechtstreeks uit het hoofdscherm
/// te lezen, dat maakt de UI-feedback trager). Elke schakelaar update
/// meteen lokaal (optimistisch), slaat daarna op, en spiegelt de wijziging
/// via [onGewijzigd] naar de lijst op het hoofdscherm (zodat de
/// status-chips daar meteen mee bijwerken); mislukt het opslaan, dan
/// herstelt de schakelaar en verschijnt een foutmelding onderaan de pop-up.
class _GebruikerBeheerDialoog extends StatefulWidget {
  const _GebruikerBeheerDialoog({
    required this.gebruiker,
    required this.meldingenGeblokkeerd,
    required this.onGewijzigd,
  });

  final Gebruiker gebruiker;

  /// `true` zolang de algemene "alle meldingen ontvangen"-schakelaar van de
  /// beheerder uit staat - dan zijn de twee meldingen-schakelaars hieronder
  /// gelocked (niet aanpasbaar), ongeacht hun eigen stand.
  final bool meldingenGeblokkeerd;

  /// Meldt een geslaagde wijziging terug aan het hoofdscherm, dat [wijzig]
  /// toepast op zijn eigen kopie van deze gebruiker in de lijst.
  final void Function(Gebruiker Function(Gebruiker) wijzig) onGewijzigd;

  @override
  State<_GebruikerBeheerDialoog> createState() =>
      _GebruikerBeheerDialoogState();
}

class _GebruikerBeheerDialoogState extends State<_GebruikerBeheerDialoog> {
  late bool _onzichtbaar;
  late bool _overzichtVerborgen;
  late bool _bulkAan;
  late bool _singleAan;
  String? _fout;

  @override
  void initState() {
    super.initState();
    _onzichtbaar = !widget.gebruiker.zichtbaarInOverzicht;
    _overzichtVerborgen = widget.gebruiker.gezamenlijkOverzichtVerborgen;
    _bulkAan = widget.gebruiker.meldingenBulkAan;
    _singleAan = widget.gebruiker.meldingenSingleAan;
  }

  Future<void> _wijzig({
    required void Function() zetLokaal,
    required void Function() herstelLokaal,
    required Future<void> Function() opslaan,
    required Gebruiker Function(Gebruiker) naarLijst,
  }) async {
    setState(() {
      _fout = null;
      zetLokaal();
    });
    try {
      await opslaan();
      widget.onGewijzigd(naarLijst);
    } catch (e) {
      setState(() {
        herstelLokaal();
        _fout = 'Kon niet opslaan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.gebruiker.uid;
    return AlertDialog(
      title: Text(widget.gebruiker.naam),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meldingen',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bij een import (PDF/schoolrooster)'),
              value: _bulkAan,
              activeThumbColor: AppKleuren.bosgroen,
              onChanged: widget.meldingenGeblokkeerd
                  ? null
                  : (waarde) => _wijzig(
                      zetLokaal: () => _bulkAan = waarde,
                      herstelLokaal: () => _bulkAan = !waarde,
                      opslaan: () =>
                          GebruikerService.zetMeldingenBulkAan(uid, waarde),
                      naarLijst: (g) => g.copyWith(meldingenBulkAan: waarde),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bij handmatig toevoegen'),
              value: _singleAan,
              activeThumbColor: AppKleuren.bosgroen,
              onChanged: widget.meldingenGeblokkeerd
                  ? null
                  : (waarde) => _wijzig(
                      zetLokaal: () => _singleAan = waarde,
                      herstelLokaal: () => _singleAan = !waarde,
                      opslaan: () =>
                          GebruikerService.zetMeldingenSingleAan(uid, waarde),
                      naarLijst: (g) => g.copyWith(meldingenSingleAan: waarde),
                    ),
            ),
            if (widget.meldingenGeblokkeerd)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Gelocked zolang "Alle meldingen ontvangen" bovenaan uit '
                  'staat.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Zichtbaarheid',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Onzichtbaar voor anderen'),
              subtitle: const Text(
                'Verschijnt dan nergens meer in het gezamenlijke overzicht '
                'voor gewone leden - enkel beheerders zien deze persoon nog.',
              ),
              value: _onzichtbaar,
              activeThumbColor: AppKleuren.bosgroen,
              onChanged: (waarde) => _wijzig(
                zetLokaal: () => _onzichtbaar = waarde,
                herstelLokaal: () => _onzichtbaar = !waarde,
                opslaan: () =>
                    GebruikerService.zetZichtbaarheid(uid, !waarde),
                naarLijst: (g) => g.copyWith(zichtbaarInOverzicht: !waarde),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gezamenlijk overzicht verbergen'),
              subtitle: const Text(
                'Deze persoon kan het gezamenlijke overzicht dan zelf niet '
                'meer openen.',
              ),
              value: _overzichtVerborgen,
              activeThumbColor: AppKleuren.bosgroen,
              onChanged: (waarde) => _wijzig(
                zetLokaal: () => _overzichtVerborgen = waarde,
                herstelLokaal: () => _overzichtVerborgen = !waarde,
                opslaan: () => GebruikerService.zetGezamenlijkOverzichtVerborgen(
                  uid,
                  waarde,
                ),
                naarLijst: (g) =>
                    g.copyWith(gezamenlijkOverzichtVerborgen: waarde),
              ),
            ),
            if (_fout != null) ...[
              const SizedBox(height: 8),
              Text(
                _fout!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Sluiten'),
        ),
      ],
    );
  }
}

class _Sectietitel extends StatelessWidget {
  const _Sectietitel(this.tekst);
  final String tekst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Text(
        tekst,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Sectiehelp extends StatelessWidget {
  const _Sectiehelp(this.tekst);
  final String tekst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Text(tekst, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _Kaart extends StatelessWidget {
  const _Kaart({required this.child, this.achtergrond});
  final Widget child;

  /// `null` = de standaard witte kaart. Gebruikt door [_GebruikerRij] om een
  /// onzichtbaar gezinslid een lichtjes gedempte achtergrond te geven, zodat
  /// dat in één oogopslag opvalt in de lijst.
  final Color? achtergrond;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: achtergrond ?? Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: child,
    );
  }
}

/// Eén rij in de gezinsledenlijst van het beheer-tab: naam + rol + status-
/// chips (F12) + de "Beheer"-knop die de instellingen-pop-up opent. Een
/// onzichtbaar gezinslid (F7) krijgt een gedempte, taupe achtergrond i.p.v.
/// wit en een doorstreept-oog-icoontje naast de naam - dat is meteen
/// zichtbaar bij het scrollen door de lijst, zonder dat je de pop-up hoeft
/// te openen om te weten wie er "onzichtbaar" staat.
class _GebruikerRij extends StatelessWidget {
  const _GebruikerRij({required this.gebruiker, required this.onBeheer});

  final Gebruiker gebruiker;
  final VoidCallback onBeheer;

  static const _gedempteAchtergrond = Color(0xFFEAE2D4);

  @override
  Widget build(BuildContext context) {
    final onzichtbaar = !gebruiker.zichtbaarInOverzicht;
    final overzichtVerborgen = gebruiker.gezamenlijkOverzichtVerborgen;

    return _Kaart(
      achtergrond: onzichtbaar ? _gedempteAchtergrond : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        gebruiker.naam,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (onzichtbaar) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.visibility_off,
                          size: 16,
                          color: AppKleuren.inkt.withValues(alpha: 0.5),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gebruiker.isBeheerder ? 'Beheerder' : 'Gezinslid',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (onzichtbaar || overzichtVerborgen) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (onzichtbaar)
                          const _StatusChip(
                            tekst: 'Onzichtbaar voor anderen',
                            icoon: Icons.visibility_off,
                          ),
                        if (overzichtVerborgen)
                          const _StatusChip(
                            tekst: 'Overzicht verborgen',
                            icoon: Icons.block,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              // Het globale FilledButtonTheme zet minimumSize op
              // Size.fromHeight(48) (= oneindig breed, bedoeld voor de
              // volle-breedte-knoppen elders in de app) - hier expliciet
              // een eindige maat, anders knalt deze knop in een Row zonder
              // Expanded.
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: onBeheer,
              child: const Text('Beheer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Klein, gedempt label-vakje ("chip") om een statusveld (F7/F12) meteen
/// zichtbaar te maken in de gezinsledenlijst - bewust in terracotta i.p.v.
/// het bosgroene "actief/aan"-kleurtje van de schakelaars elders in de app,
/// zodat het als een waarschuwing/uitzondering oogt.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.tekst, required this.icoon});

  final String tekst;
  final IconData icoon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppKleuren.terracotta.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icoon, size: 13, color: AppKleuren.terracotta),
          const SizedBox(width: 4),
          Text(
            tekst,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppKleuren.terracotta,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
