import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
/// Firebase Console (zie PROJECT_SPEC.md, sectie 11).
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

  // Wordt getoond terwijl Firebase aan het inloggen is, om de knop te
  // deactiveren en dubbele aanvragen te voorkomen.
  bool _bezigMetInloggen = false;

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
      appBar: AppBar(title: const Text('Inloggen')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: ConstrainedBox(
              // Op web/desktop niet de volle breedte gebruiken, dat oogt raar.
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Gezinsrooster',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mailadres',
                      border: OutlineInputBorder(),
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
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Wachtwoord',
                      border: OutlineInputBorder(),
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
                    // Knop uitschakelen tijdens het inloggen, zodat je niet
                    // twee keer op "Inloggen" kan klikken.
                    onPressed: _bezigMetInloggen ? null : _logIn,
                    child: _bezigMetInloggen
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Inloggen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
