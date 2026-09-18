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

  /// Alle profielen - enkel voor de beheerder (die ziet sowieso iedereen,
  /// zie firestore.rules `isBeheerder()`) of voor schermen die zelf al
  /// enkel voor de beheerder bereikbaar zijn (bv. het beheer-tab, F7).
  /// Een gewoon lid gebruikt [zichtbareGebruikers] voor het gezamenlijke
  /// overzicht (F8).
  static Future<List<Gebruiker>> alleGebruikers() async {
    final snap = await _gebruikers.get();
    return snap.docs.map(Gebruiker.vanDocument).toList();
  }

  /// Jezelf + elk gezinslid dat zichtbaar staat (F7) - voor het
  /// gezamenlijke overzicht van een gewoon lid (F8).
  ///
  /// Kan niet gewoon [alleGebruikers] gebruiken: Firestore staat een
  /// ongefilterde lijst-query niet toe als de rule daarvoor per document
  /// afhankelijk is van dat document zijn eigen data
  /// (`zichtbaarInOverzicht`) - Firestore moet vooraf kunnen garanderen dat
  /// élk mogelijk resultaat aan de rule voldoet, en dat kan enkel als de
  /// query zelf al op datzelfde veld filtert. Vandaar de expliciete
  /// `where` hier, die exact overeenkomt met de leesrule in
  /// firestore.rules.
  static Future<List<Gebruiker>> zichtbareGebruikers(String eigenUid) async {
    final snap = await _gebruikers
        .where('zichtbaarInOverzicht', isEqualTo: true)
        .get();
    final lijst = snap.docs.map(Gebruiker.vanDocument).toList();

    if (lijst.every((g) => g.uid != eigenUid)) {
      final eigenProfiel = await _gebruikers.doc(eigenUid).get();
      if (eigenProfiel.exists) lijst.add(Gebruiker.vanDocument(eigenProfiel));
    }
    return lijst;
  }

  /// Zet of dit account zichtbaar is in het gezamenlijke overzicht voor
  /// gewone leden (F7) - enkel de beheerder mag dit voor iemand anders
  /// aanpassen (zie firestore.rules, `gebruikers`-collectie).
  static Future<void> zetZichtbaarheid(String uid, bool zichtbaar) async {
    await _gebruikers.doc(uid).update({'zichtbaarInOverzicht': zichtbaar});
  }

  /// Zet je eigen bolletjeskleur in het gezamenlijke overzicht (F9) - enkel
  /// voor je eigen profiel (`eigenGebruiker(uid)` in firestore.rules), elk
  /// gezinslid kiest dit zelf.
  static Future<void> zetKleur(String uid, String hexKleur) async {
    await _gebruikers.doc(uid).update({'kleur': hexKleur});
  }

  /// Zet of acties van [uid] een melding naar de beheerder(s) sturen (F11)
  /// - enkel de beheerder mag dit voor iemand anders aanpassen (zie
  /// firestore.rules, `gebruikers`-collectie, zelfde regel als F7).
  static Future<void> zetMeldingenAan(String uid, bool aan) async {
    await _gebruikers.doc(uid).update({'meldingenAan': aan});
  }

  /// Zet je eigen "ik wil meldingen ontvangen"-schakelaar (F11) - enkel
  /// relevant als je zelf beheerder bent, en enkel voor je eigen profiel.
  static Future<void> zetWilMeldingen(String uid, bool wil) async {
    await _gebruikers.doc(uid).update({'wilMeldingen': wil});
  }

  static Future<Gebruiker> haalOfMaakProfiel(User account) async {
    final doc = await _gebruikers.doc(account.uid).get();
    if (doc.exists) {
      return Gebruiker.vanDocument(doc);
    }

    final naam = _standaardNaam(account.email);
    // zichtbaarInOverzicht altijd expliciet meegeven (i.p.v. te vertrouwen
    // op de Dart-side default `true`) - anders kan [zichtbareGebruikers]
    // dit profiel straks niet vinden, want die query filtert letterlijk op
    // `zichtbaarInOverzicht == true` (zie firestore.rules).
    await _gebruikers.doc(account.uid).set({
      'naam': naam,
      'rol': 'lid',
      'zichtbaarInOverzicht': true,
    });
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
