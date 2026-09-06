import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/models/dienst.dart';

Dienst _dienst({
  String startTijd = '09:00',
  String? eindTijd = '17:00',
  String omschrijving = '',
}) {
  return Dienst(
    gebruikerId: 'u1',
    gebruikerNaam: 'Ryan',
    datum: '2026-09-08',
    startTijd: startTijd,
    eindTijd: eindTijd,
    omschrijving: omschrijving,
    bron: DienstBron.handmatig,
    aangemaaktOp: DateTime(2026, 9, 1),
  );
}

void main() {
  group('Dienst.naarTekst', () {
    test('met begin- en einduur', () {
      expect(_dienst().naarTekst(), '09:00 - 17:00');
      expect(
        _dienst(omschrijving: 'Werk').naarTekst(),
        '09:00 - 17:00 (Werk)',
      );
    });

    test('alleen een startuur (F1)', () {
      expect(_dienst(eindTijd: null).naarTekst(), 'vanaf 09:00');
      expect(
        _dienst(eindTijd: null, omschrijving: 'Tandarts').naarTekst(),
        'vanaf 09:00 (Tandarts)',
      );
    });
  });

  group('Dienst rondrit door Firestore-map', () {
    test('eindTijd null overleeft naarDocument', () {
      expect(_dienst(eindTijd: null).naarDocument()['eindTijd'], isNull);
      expect(_dienst().naarDocument()['eindTijd'], '17:00');
    });
  });
}
