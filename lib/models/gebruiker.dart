import 'package:cloud_firestore/cloud_firestore.dart';

/// De twee rollen uit PROJECT_SPEC.md sectie 2: een gewoon gezinslid kan
/// enkel zijn/haar eigen rooster beheren, de beheerder mag daarnaast ook
/// het gezamenlijke overzicht van iedereen bekijken en printen.
enum GebruikerRol { lid, beheerder }

extension GebruikerRolWaarde on GebruikerRol {
  /// De string zoals die in Firestore opgeslagen wordt (zie ook
  /// firestore.rules, die met diezelfde strings vergelijkt).
  String get waarde {
    switch (this) {
      case GebruikerRol.beheerder:
        return 'beheerder';
      case GebruikerRol.lid:
        return 'lid';
    }
  }

  static GebruikerRol vanWaarde(String waarde) {
    return waarde == 'beheerder' ? GebruikerRol.beheerder : GebruikerRol.lid;
  }
}

/// Eén document uit de Firestore-collectie `gebruikers` (zie
/// PROJECT_SPEC.md, sectie 5). Het document-id is gelijk aan de Firebase
/// Auth uid van het account, zodat je met de uid altijd meteen het
/// bijhorende profiel (naam + rol) kan opzoeken.
class Gebruiker {
  const Gebruiker({required this.uid, required this.naam, required this.rol});

  final String uid;
  final String naam;
  final GebruikerRol rol;

  bool get isBeheerder => rol == GebruikerRol.beheerder;

  factory Gebruiker.vanDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Gebruiker(
      uid: doc.id,
      naam: data['naam'] as String,
      rol: GebruikerRolWaarde.vanWaarde(data['rol'] as String),
    );
  }
}
