import 'package:cloud_firestore/cloud_firestore.dart';

/// Waar een dienst vandaan komt: automatisch uit een geüpload PDF-rooster,
/// of met de hand ingevoerd (bv. voor privé-afspraken op het gezamenlijke
/// rooster, zie PROJECT_SPEC.md §1).
enum DienstBron { pdfImport, handmatig }

extension DienstBronWaarde on DienstBron {
  String get waarde {
    switch (this) {
      case DienstBron.pdfImport:
        return 'pdf-import';
      case DienstBron.handmatig:
        return 'handmatig';
    }
  }

  static DienstBron vanWaarde(String waarde) {
    return waarde == 'pdf-import' ? DienstBron.pdfImport : DienstBron.handmatig;
  }
}

/// Eén document uit de Firestore-collectie `diensten` (zie PROJECT_SPEC.md,
/// §4): één werkdienst (of privé-afspraak/vakantie) van één gezinslid. Dit
/// model is bewust "plat" en onafhankelijk van hoe een PDF-rooster er
/// precies uitziet, zodat elke PDF-parser (zie §6) er gewoon naartoe kan
/// vertalen zonder dat de rest van de app iets hoeft te weten van
/// PDF-lay-outs.
///
/// Een dienst kan (zie PROJECT_SPEC.md F1/F2):
/// - een begin- én einduur hebben ("09:00 - 17:00"),
/// - enkel een startuur ("vanaf 15:00", [eindTijd] is dan null),
/// - de hele dag duren ([heleDag] = true, geen uren),
/// - meerdere dagen beslaan ([eindDatum] > [datum]) - dan is het één
///   Firestore-document dat de app op elke dag in de reeks toont.
class Dienst {
  const Dienst({
    this.id,
    required this.gebruikerId,
    required this.gebruikerNaam,
    required this.datum,
    this.eindDatum,
    this.startTijd,
    this.eindTijd,
    this.heleDag = false,
    this.omschrijving = '',
    required this.bron,
    required this.aangemaaktOp,
  });

  /// Null zolang de dienst nog niet weggeschreven is naar Firestore (het
  /// document-id wordt pas gegenereerd bij het aanmaken).
  final String? id;

  final String gebruikerId;
  final String gebruikerNaam;

  /// Startdatum in ISO-formaat, bv. "2026-09-08" - puur voor opslag/
  /// sortering in Firestore, de gebruiker ziet deze string nooit
  /// rechtstreeks (schermen tonen "DD-MM-JJJJ" via `naarWeergaveDatum`).
  final String datum;

  /// Laatste dag van een meerdaagse periode (ISO), inclusief. `null` = de
  /// dienst duurt maar één dag. Bv. "vakantie 10-15 sep": [datum] =
  /// "2026-09-10", [eindDatum] = "2026-09-15".
  final String? eindDatum;

  /// bv. "09:00". `null` als [heleDag] true is.
  final String? startTijd;

  /// bv. "17:00". `null` als er enkel een startuur bekend is (F1) of als
  /// [heleDag] true is.
  final String? eindTijd;

  /// Duurt de hele dag, zonder specifieke uren (F2). Sluit begin-/einduur
  /// uit.
  final bool heleDag;

  final String omschrijving;
  final DienstBron bron;
  final DateTime aangemaaktOp;

  factory Dienst.vanDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Dienst(
      id: doc.id,
      gebruikerId: data['gebruikerId'] as String,
      gebruikerNaam: data['gebruikerNaam'] as String,
      datum: data['datum'] as String,
      eindDatum: data['eindDatum'] as String?,
      startTijd: data['startTijd'] as String?,
      eindTijd: data['eindTijd'] as String?,
      heleDag: data['heleDag'] as bool? ?? false,
      omschrijving: data['omschrijving'] as String? ?? '',
      bron: DienstBronWaarde.vanWaarde(data['bron'] as String),
      aangemaaktOp: (data['aangemaaktOp'] as Timestamp).toDate(),
    );
  }

  /// Is dit een meerdaagse periode?
  bool get isMeerdaags => eindDatum != null && eindDatum != datum;

  /// Of deze (mogelijk meerdaagse) dienst op [isoDatum] valt - gedeeld door
  /// elk scherm dat diensten per dag toont (kalender, gezamenlijk overzicht,
  /// print).
  bool valtOpDatum(String isoDatum) {
    final laatste = eindDatum ?? datum;
    return isoDatum.compareTo(datum) >= 0 && isoDatum.compareTo(laatste) <= 0;
  }

  /// De regel die in de agenda/het overzicht getoond wordt:
  /// - begin+einduur: `"09:00 - 17:00 (Werk)"`
  /// - enkel een startuur (F1): `"15:00 (Tandarts)"`
  /// - hele dag (F2): gewoon de omschrijving, bv. `"Vakantie"`
  ///
  /// Gedeeld tussen [DienstTile], het gezamenlijke overzicht en de PDF-/
  /// HTML-export ervan. [scheidingVoorOmschrijving] laat toe de omschrijving
  /// op een nieuwe regel te zetten i.p.v. een spatie.
  String naarTekst({String scheidingVoorOmschrijving = ' '}) {
    if (heleDag) {
      return omschrijving.isEmpty ? 'Hele dag' : omschrijving;
    }
    final tijd = eindTijd == null ? startTijd! : '$startTijd - $eindTijd';
    return omschrijving.isEmpty
        ? tijd
        : '$tijd$scheidingVoorOmschrijving($omschrijving)';
  }

  Map<String, dynamic> naarDocument() => {
    'gebruikerId': gebruikerId,
    'gebruikerNaam': gebruikerNaam,
    'datum': datum,
    'eindDatum': eindDatum,
    'startTijd': startTijd,
    'eindTijd': eindTijd,
    'heleDag': heleDag,
    'omschrijving': omschrijving,
    'bron': bron.waarde,
    'aangemaaktOp': Timestamp.fromDate(aangemaaktOp),
  };
}
