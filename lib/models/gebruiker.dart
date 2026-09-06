import 'package:cloud_firestore/cloud_firestore.dart';

import '../pdf_import/rooster_parser.dart';

/// De twee rollen uit PROJECT_SPEC.md §2: een gewoon gezinslid kan
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
/// PROJECT_SPEC.md, §4). Het document-id is gelijk aan de Firebase
/// Auth uid van het account, zodat je met de uid altijd meteen het
/// bijhorende profiel (naam + rol) kan opzoeken.
class Gebruiker {
  const Gebruiker({
    required this.uid,
    required this.naam,
    required this.rol,
    this.roosterFormaat,
    this.naamInRooster,
    this.webuntisKlasId,
    this.webuntisMinor,
  });

  final String uid;
  final String naam;
  final GebruikerRol rol;

  /// Welk PDF-formaat + welke naam-in-de-PDF bij dit account hoort. Staat
  /// er niet automatisch bij (`null` bij een nieuw aangemaakt profiel) -
  /// de beheerder vult dit zelf handmatig aan via de Firestore-console
  /// zodra dat gekend is (zie PROJECT_SPEC.md §8).
  final RoosterFormaat? roosterFormaat;
  final String? naamInRooster;

  /// WebUntis-klas-id (bv. `3905` voor 3ITSOF1) en het vak van de minor die
  /// dit account effectief volgt (bv. `MDI_IT_PROJIXREA` = Mixed Reality).
  /// Handmatig ingesteld in de Firestore-console; enkel Ryans account heeft
  /// dit. Zijn beide gezet, dan verschijnt de "Schoolrooster"-knop (F4).
  final int? webuntisKlasId;
  final String? webuntisMinor;

  bool get isBeheerder => rol == GebruikerRol.beheerder;

  /// Kan dit account zijn schoolrooster ophalen? (F4)
  bool get heeftSchoolrooster =>
      webuntisKlasId != null &&
      webuntisMinor != null &&
      webuntisMinor!.isNotEmpty;

  /// `null` zolang [roosterFormaat]/[naamInRooster] niet allebei ingesteld
  /// zijn - dit account kan dan nog geen PDF importeren.
  RoosterParser? maakParser() =>
      maakRoosterParser(formaat: roosterFormaat, naamInRooster: naamInRooster);

  factory Gebruiker.vanDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Gebruiker(
      uid: doc.id,
      naam: data['naam'] as String,
      rol: GebruikerRolWaarde.vanWaarde(data['rol'] as String),
      roosterFormaat: RoosterFormaatWaarde.vanWaarde(
        data['roosterFormaat'] as String?,
      ),
      naamInRooster: data['naamInRooster'] as String?,
      // Firestore kan een getal als int of double teruggeven.
      webuntisKlasId: (data['webuntisKlasId'] as num?)?.toInt(),
      webuntisMinor: data['webuntisMinor'] as String?,
    );
  }
}
