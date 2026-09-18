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

  test('FormaatAParser slaat de code "ER" over, net als "FDrec"', () {
    final bytes = File('uurroosters/uurrooster-ryan.pdf').readAsBytesSync();
    // Koen Blanpain heeft in dit rooster ergens "C8 ... ER 8u FDrec VAK"
    // naast elkaar (handmatig nagekeken) - geen van die 3 laatste codes mag
    // een werkdienst opleveren.
    final parser = FormaatAParser(naamInRooster: 'Blanpain, Koen');

    final diensten = parser.parse(
      bytes,
      gebruikerId: 'test-uid',
      gebruikerNaam: 'Koen',
    );

    // Handmatig nagekeken: dit zijn Koens enige effectieve werkdagen in
    // juli 2026 - "ER", "FDrec" en "VAK" leveren dus terecht niks op. (In
    // dit specifieke bestand stond "ER 8u" toevallig al op één tekstlijn,
    // dus de bestaande lengte-check ving die al af - deze test legt het
    // correcte resultaat vast en dekt bovendien de nieuwe, expliciete
    // "ER"/"FDrec"-check in _leesDienstenUitRij mee af.)
    expect(diensten.map((d) => d.datum).toList(), [
      '2026-07-09',
      '2026-07-10',
      '2026-07-11',
      '2026-07-25',
      '2026-07-26',
      '2026-07-27',
      '2026-07-28',
      '2026-07-30',
    ]);
    for (final dienst in diensten) {
      expect(dienst.startTijd, matches(RegExp(r'^\d{2}:\d{2}$')));
      expect(dienst.eindTijd, matches(RegExp(r'^\d{2}:\d{2}$')));
    }
  });
}
