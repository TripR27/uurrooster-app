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
    this.zichtbaarInOverzicht = true,
    this.gezamenlijkOverzichtVerborgen = false,
    this.kleur,
    this.meldingenBulkAan = true,
    this.meldingenSingleAan = true,
    this.wilMeldingen = true,
  });

  final String uid;
  final String naam;
  final GebruikerRol rol;

  /// Of dit account zichtbaar is in het gezamenlijke overzicht (F7/F8) - de
  /// beheerder zet dit per persoon in het beheer-tab. Default `true`
  /// (ontbreekt het veld nog in Firestore, dan gewoon zichtbaar). Geldt
  /// sinds F13 ook voor de beheerder zelf: onzichtbaar is echt onzichtbaar,
  /// ook op het gezamenlijke overzicht en de afdruk van een andere
  /// beheerder. Enkel het beheer-tab zelf (`alleGebruikers()`) toont nog
  /// altijd iedereen - anders zou niemand een onzichtbaar gezinslid nog
  /// terug zichtbaar kunnen zetten.
  final bool zichtbaarInOverzicht;

  /// Of **dit account zelf** het gezamenlijke overzicht mag openen (F12) -
  /// de beheerder zet dit per persoon in het beheer-tab. Staat dit op
  /// `true`, dan verdwijnt de menukaart "Gezamenlijk overzicht" op het
  /// startscherm voor deze persoon. Los van [zichtbaarInOverzicht] (dat
  /// bepaalt of ánderen deze persoon zien, dit bepaalt of deze persoon zelf
  /// het overzicht mag zien). Default `false`.
  final bool gezamenlijkOverzichtVerborgen;

  /// Hex-kleur (bv. `"#E0704F"`) van het eigen bolletje in het
  /// gezamenlijke overzicht (F9) - kiest elk gezinslid zelf, uit
  /// `kleurenPalet` (`lib/util/kleuren_palet.dart`). `null` = nog niet
  /// gekozen, dan geldt `kleurStandaardHex`.
  final String? kleur;

  /// Of een PDF-/schoolrooster-import door **dit account** een melding naar
  /// de beheerder(s) stuurt (F11/F12) - de beheerder zet dit per persoon in
  /// het beheer-tab. Default `true`.
  final bool meldingenBulkAan;

  /// Of handmatig iets toevoegen door **dit account** een melding naar de
  /// beheerder(s) stuurt (F11/F12) - los van [meldingenBulkAan], de
  /// beheerder zet dit ook per persoon in het beheer-tab. Default `true`.
  final bool meldingenSingleAan;

  /// Enkel relevant als dit account zelf beheerder is: of **deze
  /// beheerder** meldingen wil ontvangen (F11) - de algemene aan/uit-
  /// schakelaar, naast de per-persoon-toggle hierboven. Default `true`.
  final bool wilMeldingen;

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

  /// Kopie met enkel de opgegeven velden gewijzigd - vooral gebruikt voor
  /// optimistische UI-updates (bv. het beheer-tab, F7/F11) zonder alle
  /// overige velden (zoals [kleur]) per ongeluk te verliezen.
  Gebruiker copyWith({
    bool? zichtbaarInOverzicht,
    bool? gezamenlijkOverzichtVerborgen,
    String? kleur,
    bool? meldingenBulkAan,
    bool? meldingenSingleAan,
    bool? wilMeldingen,
  }) => Gebruiker(
    uid: uid,
    naam: naam,
    rol: rol,
    roosterFormaat: roosterFormaat,
    naamInRooster: naamInRooster,
    webuntisKlasId: webuntisKlasId,
    webuntisMinor: webuntisMinor,
    zichtbaarInOverzicht: zichtbaarInOverzicht ?? this.zichtbaarInOverzicht,
    gezamenlijkOverzichtVerborgen:
        gezamenlijkOverzichtVerborgen ?? this.gezamenlijkOverzichtVerborgen,
    kleur: kleur ?? this.kleur,
    meldingenBulkAan: meldingenBulkAan ?? this.meldingenBulkAan,
    meldingenSingleAan: meldingenSingleAan ?? this.meldingenSingleAan,
    wilMeldingen: wilMeldingen ?? this.wilMeldingen,
  );

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
      zichtbaarInOverzicht: data['zichtbaarInOverzicht'] as bool? ?? true,
      gezamenlijkOverzichtVerborgen:
          data['gezamenlijkOverzichtVerborgen'] as bool? ?? false,
      kleur: data['kleur'] as String?,
      // Vervangt het oude, ene `meldingenAan`-veld (F11) door twee losse
      // schakelaars (F12) - valt terug op dat oude veld als de nieuwe nog
      // niet bestaan (bestaande profielen), zodat een eerder bewust
      // uitgezette melding niet stilletjes weer aan komt te staan.
      meldingenBulkAan:
          data['meldingenBulkAan'] as bool? ??
          data['meldingenAan'] as bool? ??
          true,
      meldingenSingleAan:
          data['meldingenSingleAan'] as bool? ??
          data['meldingenAan'] as bool? ??
          true,
      wilMeldingen: data['wilMeldingen'] as bool? ?? true,
    );
  }
}
