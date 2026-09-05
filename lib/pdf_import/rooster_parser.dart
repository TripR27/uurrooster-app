import 'dart:typed_data';

import '../models/dienst.dart';
import 'formaat_a_parser.dart';
import 'formaat_b_parser.dart';

/// Elk rooster-PDF-formaat (zie PROJECT_SPEC.md sectie 6) krijgt zijn eigen
/// klasse die dit implementeert. De rest van de app moet nooit weten hoe
/// een specifiek PDF-formaat er precies uitziet - enkel dat er ergens een
/// lijst Diensten uitkomt.
abstract class RoosterParser {
  List<Dienst> parse(
    Uint8List pdfBytes, {
    required String gebruikerId,
    required String gebruikerNaam,
  });
}

/// Welk PDF-formaat bij een account hoort - opgeslagen als `roosterFormaat`
/// op het Firestore-document van die gebruiker (zie models/gebruiker.dart).
enum RoosterFormaat { a, b }

extension RoosterFormaatWaarde on RoosterFormaat {
  String get waarde => this == RoosterFormaat.a ? 'A' : 'B';

  static RoosterFormaat? vanWaarde(String? waarde) {
    switch (waarde) {
      case 'A':
        return RoosterFormaat.a;
      case 'B':
        return RoosterFormaat.b;
      default:
        return null;
    }
  }
}

/// Maakt de juiste [RoosterParser] voor een account, op basis van zijn
/// `roosterFormaat` + `naamInRooster` (zie models/gebruiker.dart). Geeft
/// `null` terug als één van beide nog niet is ingesteld door de beheerder
/// (nieuwe accounts hebben dit nog niet, zie ACCOUNTS_AANMAKEN.md).
RoosterParser? maakRoosterParser({
  required RoosterFormaat? formaat,
  required String? naamInRooster,
}) {
  if (formaat == null || naamInRooster == null || naamInRooster.isEmpty) {
    return null;
  }
  switch (formaat) {
    case RoosterFormaat.a:
      return FormaatAParser(naamInRooster: naamInRooster);
    case RoosterFormaat.b:
      return FormaatBParser(naamInRooster: naamInRooster);
  }
}
