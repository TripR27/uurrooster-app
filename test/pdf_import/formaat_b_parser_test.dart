import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/pdf_import/formaat_b_parser.dart';

void main() {
  test('FormaatBParser leest Amy haar shiften uit het echte rooster', () {
    final bytes = File('uurroosters/uurrooster-zus.pdf').readAsBytesSync();
    final parser = FormaatBParser(naamInRooster: 'Amy');

    final diensten = parser.parse(
      bytes,
      gebruikerId: 'test-uid',
      gebruikerNaam: 'Amy',
    );

    // Handmatig nagekeken in het PDF-bestand.
    expect(diensten.map((d) => d.datum).toList(), [
      '2026-06-29',
      '2026-06-30',
      '2026-07-08',
      '2026-07-09',
      '2026-07-11',
      '2026-07-12',
      '2026-07-16',
      '2026-07-17',
      '2026-07-20',
      '2026-07-21',
      '2026-07-24',
      '2026-07-26',
      '2026-07-28',
      '2026-07-31',
      '2026-08-01',
      '2026-08-06',
      '2026-08-07',
      '2026-08-08',
      '2026-08-10',
      '2026-08-13',
      '2026-08-14',
      '2026-08-17',
      '2026-08-20',
      '2026-08-21',
      '2026-08-23',
    ]);

    // Gewone dienst, geen nachtcode.
    final gewoneDienst = diensten.firstWhere((d) => d.datum == '2026-06-29');
    expect(gewoneDienst.startTijd, '07:00');
    expect(gewoneDienst.eindTijd, '17:00');
    expect(gewoneDienst.omschrijving, 'Werk');

    // "20 N 9" op zondag 12 juli -> nacht van 20u tot 9u, zelfde dag.
    final nachtDienst = diensten.firstWhere((d) => d.datum == '2026-07-12');
    expect(nachtDienst.startTijd, '20:00');
    expect(nachtDienst.eindTijd, '09:00');
    expect(nachtDienst.omschrijving, 'Nacht');
  });
}
