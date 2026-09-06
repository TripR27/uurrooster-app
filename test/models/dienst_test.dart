import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/models/dienst.dart';

Dienst _dienst({
  String datum = '2026-09-08',
  String? eindDatum,
  String? startTijd = '09:00',
  String? eindTijd = '17:00',
  bool heleDag = false,
  String omschrijving = '',
}) {
  return Dienst(
    gebruikerId: 'u1',
    gebruikerNaam: 'Ryan',
    datum: datum,
    eindDatum: eindDatum,
    startTijd: startTijd,
    eindTijd: eindTijd,
    heleDag: heleDag,
    omschrijving: omschrijving,
    bron: DienstBron.handmatig,
    aangemaaktOp: DateTime(2026, 9, 1),
  );
}

void main() {
  group('Dienst.naarTekst', () {
    test('met begin- en einduur', () {
      expect(_dienst().naarTekst(), '09:00 - 17:00');
      expect(_dienst(omschrijving: 'Werk').naarTekst(), '09:00 - 17:00 (Werk)');
    });

    test('alleen een startuur (F1) - zonder "vanaf"', () {
      expect(_dienst(eindTijd: null).naarTekst(), '09:00');
      expect(
        _dienst(eindTijd: null, omschrijving: 'Tandarts').naarTekst(),
        '09:00 (Tandarts)',
      );
    });

    test('hele dag (F2) - enkel de omschrijving', () {
      expect(
        _dienst(
          heleDag: true,
          startTijd: null,
          eindTijd: null,
          omschrijving: 'Vakantie',
        ).naarTekst(),
        'Vakantie',
      );
      // Terugval als er toch geen omschrijving is.
      expect(
        _dienst(heleDag: true, startTijd: null, eindTijd: null).naarTekst(),
        'Hele dag',
      );
    });
  });

  group('Dienst.valtOpDatum (F2)', () {
    test('eendaagse dienst', () {
      final d = _dienst(datum: '2026-09-08');
      expect(d.valtOpDatum('2026-09-08'), isTrue);
      expect(d.valtOpDatum('2026-09-09'), isFalse);
      expect(d.isMeerdaags, isFalse);
    });

    test('meerdaagse periode - inclusief begin en einde', () {
      final d = _dienst(datum: '2026-09-10', eindDatum: '2026-09-15');
      expect(d.isMeerdaags, isTrue);
      expect(d.valtOpDatum('2026-09-09'), isFalse);
      expect(d.valtOpDatum('2026-09-10'), isTrue);
      expect(d.valtOpDatum('2026-09-13'), isTrue);
      expect(d.valtOpDatum('2026-09-15'), isTrue);
      expect(d.valtOpDatum('2026-09-16'), isFalse);
    });
  });

  group('Dienst rondrit door de Firestore-map', () {
    test('nieuwe velden overleven naarDocument', () {
      final map = _dienst(
        eindDatum: '2026-09-15',
        startTijd: null,
        eindTijd: null,
        heleDag: true,
      ).naarDocument();
      expect(map['eindDatum'], '2026-09-15');
      expect(map['startTijd'], isNull);
      expect(map['eindTijd'], isNull);
      expect(map['heleDag'], isTrue);
    });
  });
}
