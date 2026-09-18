import 'package:flutter/material.dart';

import '../models/gebruiker.dart';
import '../services/gebruiker_service.dart';
import '../theme.dart';

/// Het "Beheer"-tabje, enkel bereikbaar voor de beheerder (zie
/// PROJECT_SPEC.md F7): per gezinslid instellen of die persoon zichtbaar is
/// in het gezamenlijke overzicht (F8). Onzichtbaar = die persoon (en
/// zijn/haar shiften) verschijnt nergens in het gezamenlijke overzicht of
/// de afdruk voor gewone leden - enkel beheerders zien hem/haar nog. Dat
/// geldt ook voor een ander beheerder-account (bv. een testaccount).
class BeheerInstellingenScreen extends StatefulWidget {
  const BeheerInstellingenScreen({super.key});

  @override
  State<BeheerInstellingenScreen> createState() =>
      _BeheerInstellingenScreenState();
}

class _BeheerInstellingenScreenState extends State<BeheerInstellingenScreen> {
  late Future<List<Gebruiker>> _gebruikers;

  @override
  void initState() {
    super.initState();
    _gebruikers = GebruikerService.alleGebruikers();
  }

  Future<void> _zetZichtbaarheid(Gebruiker gebruiker, bool zichtbaar) async {
    // Optimistisch bijwerken zodat de schakelaar meteen reageert, i.p.v. te
    // wachten op een herlaad van de hele lijst.
    setState(() {
      _gebruikers = _gebruikers.then(
        (lijst) => [
          for (final g in lijst)
            if (g.uid == gebruiker.uid)
              Gebruiker(
                uid: g.uid,
                naam: g.naam,
                rol: g.rol,
                roosterFormaat: g.roosterFormaat,
                naamInRooster: g.naamInRooster,
                webuntisKlasId: g.webuntisKlasId,
                webuntisMinor: g.webuntisMinor,
                zichtbaarInOverzicht: zichtbaar,
              )
            else
              g,
        ],
      );
    });
    try {
      await GebruikerService.zetZichtbaarheid(gebruiker.uid, zichtbaar);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kon niet opslaan: $e')));
      setState(() => _gebruikers = GebruikerService.alleGebruikers());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beheer')),
      body: SafeArea(
        child: FutureBuilder<List<Gebruiker>>(
          future: _gebruikers,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
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

            final gebruikers = snapshot.data!
              ..sort((a, b) => a.naam.compareTo(b.naam));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    'Zichtbaarheid gezamenlijk overzicht',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  child: Text(
                    'Een onzichtbaar gezinslid verschijnt nergens in het '
                    'gezamenlijke overzicht of de afdruk voor gewone leden - '
                    'enkel beheerders zien die persoon nog.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                for (final gebruiker in gebruikers) ...[
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 1,
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
              ],
            );
          },
        ),
      ),
    );
  }
}
