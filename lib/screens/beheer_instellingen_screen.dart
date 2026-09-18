import 'package:flutter/material.dart';

import '../models/gebruiker.dart';
import '../services/gebruiker_service.dart';
import '../theme.dart';

/// Het "Beheer"-tabje, enkel bereikbaar voor de beheerder (zie
/// PROJECT_SPEC.md F7): per gezinslid instellen of die persoon zichtbaar is
/// in het gezamenlijke overzicht (F8) en of diens acties een melding naar
/// de beheerder(s) sturen (F11), + een algemene "ik wil meldingen
/// ontvangen"-schakelaar voor de ingelogde beheerder zelf. Onzichtbaar = die
/// persoon (en zijn/haar shiften) verschijnt nergens in het gezamenlijke
/// overzicht of de afdruk voor gewone leden - enkel beheerders zien hem/haar
/// nog. Dat geldt ook voor een ander beheerder-account (bv. een
/// testaccount).
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
      lijst.sort((a, b) => a.naam.compareTo(b.naam));
      return _lijst = lijst;
    });
  }

  Future<void> _herlaad() async {
    final lijst = await GebruikerService.alleGebruikers();
    lijst.sort((a, b) => a.naam.compareTo(b.naam));
    if (mounted) setState(() => _lijst = lijst);
  }

  /// Werkt [uid] optimistisch bij in de lokale lijst (zodat de schakelaar
  /// meteen reageert i.p.v. te wachten op een herlaad), en stuurt [opslaan]
  /// naar Firestore. Mislukt dat, dan herstelt de lijst naar de echte
  /// serverstatus.
  Future<void> _bijwerken(
    String uid,
    Gebruiker Function(Gebruiker) wijzig,
    Future<void> Function() opslaan,
  ) async {
    setState(() {
      _lijst = [
        for (final g in _lijst!)
          if (g.uid == uid) wijzig(g) else g,
      ];
    });
    try {
      await opslaan();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kon niet opslaan: $e')));
      await _herlaad();
    }
  }

  Future<void> _zetZichtbaarheid(Gebruiker gebruiker, bool zichtbaar) =>
      _bijwerken(
        gebruiker.uid,
        (g) => g.copyWith(zichtbaarInOverzicht: zichtbaar),
        () => GebruikerService.zetZichtbaarheid(gebruiker.uid, zichtbaar),
      );

  Future<void> _zetMeldingenAan(Gebruiker gebruiker, bool aan) => _bijwerken(
    gebruiker.uid,
    (g) => g.copyWith(meldingenAan: aan),
    () => GebruikerService.zetMeldingenAan(gebruiker.uid, aan),
  );

  Future<void> _zetWilMeldingen(bool wil) => _bijwerken(
    widget.profiel.uid,
    (g) => g.copyWith(wilMeldingen: wil),
    () => GebruikerService.zetWilMeldingen(widget.profiel.uid, wil),
  );

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
                _Sectietitel('Zichtbaarheid gezamenlijk overzicht'),
                _Sectiehelp(
                  'Een onzichtbaar gezinslid verschijnt nergens in het '
                  'gezamenlijke overzicht of de afdruk voor gewone leden - '
                  'enkel beheerders zien die persoon nog.',
                ),
                for (final gebruiker in gebruikers) ...[
                  _Kaart(
                    child: SwitchListTile(
                      title: Text(gebruiker.naam),
                      subtitle: Text(
                        gebruiker.isBeheerder ? 'Beheerder' : 'Gezinslid',
                      ),
                      value: gebruiker.zichtbaarInOverzicht,
                      activeThumbColor: AppKleuren.bosgroen,
                      onChanged: (waarde) =>
                          _zetZichtbaarheid(gebruiker, waarde),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 20),
                _Sectietitel('Meldingen'),
                _Sectiehelp(
                  'Als iemand een PDF inleest, het schoolrooster ophaalt of '
                  'zelf iets toevoegt, kan een beheerder daar een '
                  'pushmelding van krijgen.',
                ),
                _Kaart(
                  child: SwitchListTile(
                    title: const Text('Ik wil meldingen ontvangen'),
                    subtitle: const Text(
                      'Algemene schakelaar voor jou als beheerder',
                    ),
                    value: eigenProfiel.wilMeldingen,
                    activeThumbColor: AppKleuren.bosgroen,
                    onChanged: _zetWilMeldingen,
                  ),
                ),
                const SizedBox(height: 16),
                for (final gebruiker in gebruikers) ...[
                  _Kaart(
                    child: SwitchListTile(
                      title: Text(gebruiker.naam),
                      subtitle: const Text('Stuurt meldingen bij een actie'),
                      value: gebruiker.meldingenAan,
                      activeThumbColor: AppKleuren.bosgroen,
                      onChanged: (waarde) =>
                          _zetMeldingenAan(gebruiker, waarde),
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
  const _Kaart({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: child,
    );
  }
}
