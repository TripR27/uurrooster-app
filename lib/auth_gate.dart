import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
          return const LoginScreen();
        }
        return const HomeScreen();
      },
    );
  }
}
