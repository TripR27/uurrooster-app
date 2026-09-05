import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/pdf_import/formaat_a_parser.dart';

void main() {
  test('FormaatAParser leest Ryan zijn shiften uit het echte rooster', () {
    final bytes = File('uurroosters/uurrooster-ryan.pdf').readAsBytesSync();
    final parser = FormaatAParser(naamInRooster: 'Wyters, Ryan');

    final diensten = parser.parse(
      bytes,
      gebruikerId: 'test-uid',
      gebruikerNaam: 'Ryan',
    );

    // Handmatig nagekeken in het PDF-bestand: dit zijn de enige dagen in
    // juli 2026 waarop Ryan effectief moet werken (de rest is leeg of
    // "FDrec").
    expect(diensten.map((d) => d.datum).toList(), [
      '2026-07-04',
      '2026-07-05',
      '2026-07-06',
      '2026-07-07',
      '2026-07-12',
      '2026-07-17',
      '2026-07-18',
      '2026-07-19',
      '2026-07-21',
    ]);
    expect(diensten[0].startTijd, '08:30');
    expect(diensten[0].eindTijd, '14:30');
    expect(diensten[0].omschrijving, 'Werk');
    expect(diensten[4].startTijd, '10:00');
    expect(diensten[4].eindTijd, '16:30');
  });
}
