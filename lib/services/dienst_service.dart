import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dienst.dart';

/// Leest en schrijft de Firestore-collectie `diensten` (zie
/// PROJECT_SPEC.md, sectie 5).
class DienstService {
  DienstService._();

  static final _diensten = FirebaseFirestore.instance.collection('diensten');

  /// Schrijft het resultaat van een PDF-import weg. Elke dienst krijgt als
  /// document-id `{gebruikerId}_{datum}` (zie PROJECT_SPEC.md, sectie 5) -
  /// een herhaalde import van dezelfde periode overschrijft dus gewoon de
  /// vorige waarde in plaats van duplicaten aan te maken.
  static Future<void> slaPdfImportOp(List<Dienst> diensten) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final dienst in diensten) {
      final id = '${dienst.gebruikerId}_${dienst.datum}';
      batch.set(_diensten.doc(id), dienst.naarDocument());
    }
    await batch.commit();
  }

  /// Alle diensten van één gebruiker, oplopend gesorteerd op datum. Gebruikt
  /// door het overzichtscherm (latere stap) en om een PDF-import hier al
  /// meteen te kunnen verifiëren.
  ///
  /// Sorteert bewust in Dart i.p.v. met `.orderBy('datum')` in de query:
  /// dat laatste zou een samengestelde Firestore-index vereisen (gelijkheid
  /// op `gebruikerId` + sortering op `datum`), die er nu niet is en die de
  /// beheerder dan manueel zou moeten aanmaken in de Firebase Console.
  static Stream<List<Dienst>> eigenDiensten(String gebruikerId) {
    return _diensten
        .where('gebruikerId', isEqualTo: gebruikerId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(Dienst.vanDocument).toList()
                ..sort((a, b) => a.datum.compareTo(b.datum)),
        );
  }
}
