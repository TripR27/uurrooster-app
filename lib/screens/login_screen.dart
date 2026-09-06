import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Inlogscherm met e-mail + wachtwoord.
///
/// Dit scherm meldt de gebruiker aan bij Firebase Authentication. Als het
/// inloggen lukt, verandert `FirebaseAuth.instance.authStateChanges()` van
/// waarde en schakelt de [AuthGate] (zie auth_gate.dart) automatisch door
/// naar het beveiligde deel van de app — dit scherm hoeft zelf niet te
/// navigeren.
///
/// Er is bewust GEEN "registreer je hier"-optie: dit is een privé-gezinsapp
/// met maar 3 accounts, die de beheerder zelf handmatig aanmaakt via de
/// Firebase Console (zie PROJECT_SPEC.md, §8).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // GlobalKey geeft toegang tot de Form, o.a. om validate() aan te roepen.
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Wordt getoond terwijl Firebase aan het inloggen is: de knop toont dan
  // een laadcirkel i.p.v. "Inloggen" (zie FilledButton hieronder) en wordt
  // gedeactiveerd om dubbele aanvragen te voorkomen.
  bool _bezigMetInloggen = false;

  // Of het wachtwoordveld leesbare tekst toont i.p.v. bolletjes. Aan/uit
  // via het oog-icoontje naast het veld.
  bool _wachtwoordZichtbaar = false;

  // Foutmelding van Firebase (bv. "verkeerd wachtwoord"), leeg = geen fout.
  String? _foutmelding;

  @override
  void dispose() {
    // Controllers altijd opruimen om geheugenlekken te voorkomen.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    // Eerst de veldvalidatie (leeg/ongeldig e-mailadres) laten lopen; pas
    // daarna Firebase benaderen.
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _bezigMetInloggen = true;
      _foutmelding = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Geen navigatie nodig: AuthGate luistert naar authStateChanges en
      // toont automatisch het volgende scherm zodra het inloggen lukt.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _foutmelding = _vertaalFoutmelding(e.code);
      });
    } finally {
      // `mounted` check: als de gebruiker intussen van scherm wisselde
      // (bv. AuthGate toont al de volgende pagina), niet meer setState
      // aanroepen op een widget die niet meer bestaat.
      if (mounted) {
        setState(() {
          _bezigMetInloggen = false;
        });
      }
    }
  }

  /// Vertaalt Firebase-foutcodes naar begrijpelijke Nederlandse tekst.
  String _vertaalFoutmelding(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Dit e-mailadres is ongeldig.';
      case 'user-disabled':
        return 'Dit account is uitgeschakeld.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'E-mailadres of wachtwoord is onjuist.';
      case 'wrong-password':
        return 'E-mailadres of wachtwoord is onjuist.';
      case 'too-many-requests':
        return 'Te veel pogingen. Probeer het later opnieuw.';
      default:
        return 'Inloggen is mislukt (code: $code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Geen AppBar hier: de branding zit al in het linkerpaneel (breed
      // scherm) of de gekleurde kop (smal scherm), zie hieronder.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Vanaf ~800px breed is er ruimte voor een split-layout met een
            // apart brandingpaneel; daaronder (telefoon/smal browserraam)
            // valt dat weg en tonen we enkel het formulier met een
            // gekleurde kop erboven.
            final breedScherm = constraints.maxWidth >= 800;

            if (breedScherm) {
              return Row(
                children: [
                  Expanded(child: _BrandingPaneel()),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: _inlogFormulier(context),
                      ),
                    ),
                  ),
                ],
              );
            }

            // Zodra het toetsenbord open staat de kop-banner verbergen:
            // anders moet je op een klein telefoonscherm steeds voorbij die
            // vaste ~140px scrollen om te zien wat je aan het intikken bent.
            final toetsenbordOpen =
                MediaQuery.of(context).viewInsets.bottom > 0;

            return SingleChildScrollView(
              child: Column(
                children: [
                  if (!toetsenbordOpen) const _BrandingBanner(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _inlogFormulier(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _inlogFormulier(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Inloggen', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Log in met je email'),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (waarde) {
                if (waarde == null || waarde.trim().isEmpty) {
                  return 'Vul je e-mailadres in.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              // Bolletjes tonen, tenzij de gebruiker op het oog-icoontje
              // drukt om het ingevoerde wachtwoord even te controleren.
              obscureText: !_wachtwoordZichtbaar,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Wachtwoord',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _wachtwoordZichtbaar
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  tooltip: _wachtwoordZichtbaar
                      ? 'Wachtwoord verbergen'
                      : 'Wachtwoord tonen',
                  onPressed: () {
                    setState(
                      () => _wachtwoordZichtbaar = !_wachtwoordZichtbaar,
                    );
                  },
                ),
              ),
              // Enter in het wachtwoordveld logt meteen in.
              onFieldSubmitted: (_) => _logIn(),
              validator: (waarde) {
                if (waarde == null || waarde.isEmpty) {
                  return 'Vul je wachtwoord in.';
                }
                return null;
              },
            ),
            if (_foutmelding != null) ...[
              const SizedBox(height: 16),
              Text(
                _foutmelding!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              // Knop uitschakelen tijdens het inloggen, zodat je niet twee
              // keer op "Inloggen" kan klikken. De laadcirkel vervangt de
              // knoptekst zodat duidelijk zichtbaar is dat er iets gebeurt.
              onPressed: _bezigMetInloggen ? null : _logIn,
              child: _bezigMetInloggen
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Inloggen'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gekleurd brandingpaneel voor de linkerhelft van het scherm op brede
/// (desktop/tablet) schermen.
class _BrandingPaneel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppKleuren.bosgroenDonker,
      padding: const EdgeInsets.all(48),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.calendar_month, color: AppKleuren.terracotta, size: 48),
            SizedBox(height: 24),
            Text(
              'Mama\'s rooster app',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Zodat ons moeder ni meer hoeft te zagen!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compacte variant van [_BrandingPaneel] als kop boven het formulier op
/// smalle (telefoon) schermen, waar geen ruimte is voor een zij-paneel.
class _BrandingBanner extends StatelessWidget {
  const _BrandingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppKleuren.bosgroenDonker,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: const Column(
        children: [
          Icon(Icons.calendar_month, color: AppKleuren.terracotta, size: 36),
          SizedBox(height: 12),
          Text(
            'Mama\'s rooster app',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
