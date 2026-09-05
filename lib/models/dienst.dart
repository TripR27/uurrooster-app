import 'package:cloud_firestore/cloud_firestore.dart';

/// Waar een dienst vandaan komt: automatisch uit een geüpload PDF-rooster,
/// of met de hand ingevoerd (bv. voor privé-afspraken op het gezamenlijke
/// rooster, zie PROJECT_SPEC.md sectie 1).
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
/// sectie 5): één werkdienst (of privé-afspraak) van één gezinslid op één
/// dag. Dit model is bewust "plat" en onafhankelijk van hoe een PDF-rooster
/// er precies uitziet, zodat elke PDF-parser (zie sectie 6) er gewoon
/// naartoe kan vertalen zonder dat de rest van de app iets hoeft te weten
/// van PDF-lay-outs.
class Dienst {
  const Dienst({
    this.id,
    required this.gebruikerId,
    required this.gebruikerNaam,
    required this.datum,
    required this.startTijd,
    required this.eindTijd,
    this.omschrijving = '',
    required this.bron,
    required this.aangemaaktOp,
  });

  /// Null zolang de dienst nog niet weggeschreven is naar Firestore (het
  /// document-id wordt pas gegenereerd bij het aanmaken).
  final String? id;

  final String gebruikerId;
  final String gebruikerNaam;

  /// ISO-formaat, bv. "2026-09-08" - makkelijk sorteren als tekst.
  final String datum;

  /// bv. "09:00".
  final String startTijd;

  /// bv. "17:00".
  final String eindTijd;

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
      startTijd: data['startTijd'] as String,
      eindTijd: data['eindTijd'] as String,
      omschrijving: data['omschrijving'] as String? ?? '',
      bron: DienstBronWaarde.vanWaarde(data['bron'] as String),
      aangemaaktOp: (data['aangemaaktOp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> naarDocument() => {
    'gebruikerId': gebruikerId,
    'gebruikerNaam': gebruikerNaam,
    'datum': datum,
    'startTijd': startTijd,
    'eindTijd': eindTijd,
    'omschrijving': omschrijving,
    'bron': bron.waarde,
    'aangemaaktOp': Timestamp.fromDate(aangemaaktOp),
  };
}
