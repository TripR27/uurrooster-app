import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

/// Bepaalt of de gebruiker het inlogscherm of het beveiligde deel van de
/// app te zien krijgt, op basis van de actuele Firebase-inlogstatus.
///
/// `authStateChanges()` is een Stream die een nieuwe waarde uitzendt
/// telkens wanneer een gebruiker inlogt of uitlogt (en éénmalig bij het
/// opstarten van de app, met de dan al gecachte login-status). Door hier
/// met een [StreamBuilder] op te reageren, hoeven LoginScreen en HomeScreen
/// zelf geen navigatie te regelen: inloggen/uitloggen doet dat automatisch.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Nog geen antwoord van Firebase gehad (gebeurt kort bij het
        // opstarten): toon een laadindicator i.p.v. even het inlogscherm
        // te flitsen.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final gebruiker = snapshot.data;
        if (gebruiker == null) {
          _ontkoppelOneSignal();
          return const LoginScreen();
        }
        _koppelOneSignal(gebruiker.uid);
        return const HomeScreen();
      },
    );
  }
}

/// Laatst gekoppelde uid - voorkomt dat elke rebuild van [AuthGate] (bv.
/// bij een Firestore-snapshot elders in de boom) opnieuw `OneSignal.login`
/// aanroept voor dezelfde, al gekoppelde gebruiker.
String? _laatstGekoppeldeUid;

/// Koppelt dit toestel aan de Firebase-uid als OneSignal "External ID"
/// (F11) - zo weet `MeldingService` exact wie een melding moet krijgen,
/// zonder zelf device-tokens te moeten bijhouden. Enkel op Android: de
/// webversie wordt niet publiek gehost en heeft geen OneSignal-config
/// (zie main.dart).
void _koppelOneSignal(String uid) {
  if (kIsWeb || _laatstGekoppeldeUid == uid) return;
  _laatstGekoppeldeUid = uid;
  OneSignal.login(uid);
  OneSignal.Notifications.requestPermission(true);
}

/// Ontkoppelt bij het uitloggen - anders zou een volgende inlog op
/// hetzelfde toestel (bv. tijdens testen, met een ander testaccount) de
/// meldingen nog naar de vorige gebruiker sturen.
void _ontkoppelOneSignal() {
  if (kIsWeb || _laatstGekoppeldeUid == null) return;
  _laatstGekoppeldeUid = null;
  OneSignal.logout();
}
