import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/gebruiker.dart';

/// Haalt het Firestore-profiel (collectie `gebruikers`) van een ingelogd
/// account op, en maakt het automatisch aan bij de allereerste keer
/// inloggen.
///
/// Nieuwe profielen krijgen altijd rol 'lid' — dat is met opzet, want de
/// Firestore security rules (zie firestore.rules in de projectroot) staan
/// niet toe dat een account zichzelf een andere rol geeft. Om iemand
/// beheerder te maken past de beheerder dat veld handmatig aan in de
/// Firebase Console (zie ACCOUNTS_AANMAKEN.md) — dat omzeilt de rules, want
/// de Console werkt met eigenaarsrechten.
class GebruikerService {
  GebruikerService._();

  static final _gebruikers = FirebaseFirestore.instance.collection(
    'gebruikers',
  );

  /// Alle profielen, voor het gezamenlijke overzicht (enkel de beheerder mag
  /// dit aanroepen - zie firestore.rules, `isBeheerder()` staat lezen van
  /// alle `gebruikers`-documenten toe voor dat account).
  static Future<List<Gebruiker>> alleGebruikers() async {
    final snap = await _gebruikers.get();
    return snap.docs.map(Gebruiker.vanDocument).toList();
  }

  static Future<Gebruiker> haalOfMaakProfiel(User account) async {
    final doc = await _gebruikers.doc(account.uid).get();
    if (doc.exists) {
      return Gebruiker.vanDocument(doc);
    }

    final naam = _standaardNaam(account.email);
    await _gebruikers.doc(account.uid).set({'naam': naam, 'rol': 'lid'});
    return Gebruiker(uid: account.uid, naam: naam, rol: GebruikerRol.lid);
  }

  /// Bij gebrek aan een expliciet ingevoerde naam gebruiken we het stukje
  /// van het e-mailadres vóór de '@', met een hoofdletter — bv.
  /// "amy@gmail.com" wordt "Amy". De beheerder kan dit nadien nog aanpassen
  /// in de Firebase Console.
  static String _standaardNaam(String? email) {
    if (email == null || !email.contains('@')) return 'Onbekend';
    final lokaalDeel = email.split('@').first;
    if (lokaalDeel.isEmpty) return 'Onbekend';
    return lokaalDeel[0].toUpperCase() + lokaalDeel.substring(1);
  }
}
