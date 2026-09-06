import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dienst.dart';

/// Leest en schrijft de Firestore-collectie `diensten` (zie
/// PROJECT_SPEC.md, §4).
class DienstService {
  DienstService._();

  static final _diensten = FirebaseFirestore.instance.collection('diensten');

  /// Schrijft het resultaat van een PDF-import weg. Elke dienst krijgt als
  /// document-id `{gebruikerId}_{datum}` (zie PROJECT_SPEC.md, §4) -
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

  /// Schrijft de uit WebUntis opgehaalde schooldagen weg voor één gebruiker
  /// en één maand (F4). Elke dag krijgt document-id `{gebruikerId}_school_
  /// {datum}` zodat opnieuw ophalen gewoon overschrijft. School-diensten van
  /// diezelfde maand die er niet meer zijn (les afgelast, vakantie) worden
  /// verwijderd.
  static Future<void> slaSchoolroosterOp({
    required String gebruikerId,
    required List<Dienst> diensten,
    required int jaar,
    required int maand,
  }) async {
    final prefix = '${gebruikerId}_school_';
    final maandStr =
        '${jaar.toString().padLeft(4, '0')}-${maand.toString().padLeft(2, '0')}';

    final bestaand = await _diensten
        .where('gebruikerId', isEqualTo: gebruikerId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    final nieuweIds = <String>{};
    for (final dienst in diensten) {
      final id = '$prefix${dienst.datum}';
      nieuweIds.add(id);
      batch.set(_diensten.doc(id), dienst.naarDocument());
    }
    for (final doc in bestaand.docs) {
      if (doc.id.startsWith(prefix) &&
          doc.id.substring(prefix.length).startsWith(maandStr) &&
          !nieuweIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  /// Voegt een nieuwe handmatige dienst toe (bv. een privé-afspraak, zie
  /// PROJECT_SPEC.md §1) met een automatisch gegenereerd document-id -
  /// in tegenstelling tot een PDF-import kunnen er zo wel meerdere diensten
  /// per dag per gebruiker bestaan (bv. een werkdienst + een afspraak).
  static Future<void> aanmaken(Dienst dienst) async {
    assert(
      dienst.id == null,
      'aanmaken() is enkel voor een nog niet opgeslagen dienst',
    );
    await _diensten.add(dienst.naarDocument());
  }

  /// Werkt een bestaande dienst bij (bv. een verkeerd ingelezen uur
  /// corrigeren) - [dienst.id] moet dus al bestaan.
  static Future<void> bijwerken(Dienst dienst) async {
    assert(dienst.id != null, 'bijwerken() kan enkel op een bestaande dienst');
    await _diensten.doc(dienst.id).update(dienst.naarDocument());
  }

  /// Verwijdert een dienst (bv. een fout ingelezen dag, of een privé-
  /// afspraak die niet meer doorgaat).
  static Future<void> verwijderen(String dienstId) async {
    await _diensten.doc(dienstId).delete();
  }

  /// Alle diensten van één gebruiker, oplopend gesorteerd op datum. Gebruikt
  /// door het overzichtscherm en om een PDF-import hier al meteen te kunnen
  /// verifiëren.
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

  /// Alle diensten van meerdere gebruikers binnen een periode (beide data
  /// inbegrepen) - voor het gezamenlijke overzicht van de beheerder (zie
  /// PROJECT_SPEC.md, §5).
  ///
  /// Doet bewust één losse query per gebruiker (zelfde `where('gebruikerId')`
  /// als [eigenDiensten]) i.p.v. één query met `whereIn` + een datumfilter:
  /// die combinatie zou een samengestelde Firestore-index vereisen. De
  /// periode wordt dus, net als de sortering elders in deze klasse, gewoon
  /// in Dart gefilterd.
  static Future<List<Dienst>> voorPeriode({
    required List<String> gebruikerIds,
    required String vanIso,
    required String totIso,
  }) async {
    final snapshots = await Future.wait(
      gebruikerIds.map(
        (id) => _diensten.where('gebruikerId', isEqualTo: id).get(),
      ),
    );
    return snapshots
        .expand((snap) => snap.docs.map(Dienst.vanDocument))
        .where(
          (d) =>
              d.datum.compareTo(vanIso) >= 0 && d.datum.compareTo(totIso) <= 0,
        )
        .toList()
      ..sort((a, b) => a.datum.compareTo(b.datum));
  }
}
