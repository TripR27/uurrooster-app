import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/models/gebruiker.dart';
import 'package:uurrooster_app/services/melding_service.dart';

Gebruiker _gebruiker({
  required String uid,
  required GebruikerRol rol,
  bool meldingenBulkAan = true,
  bool meldingenSingleAan = true,
  bool wilMeldingen = true,
}) {
  return Gebruiker(
    uid: uid,
    naam: uid,
    rol: rol,
    meldingenBulkAan: meldingenBulkAan,
    meldingenSingleAan: meldingenSingleAan,
    wilMeldingen: wilMeldingen,
  );
}

void main() {
  group('MeldingService.bepaalOntvangers', () {
    test('beheerders met wilMeldingen krijgen een melding (bulk)', () {
      final ryan = _gebruiker(uid: 'ryan', rol: GebruikerRol.beheerder);
      final amy = _gebruiker(uid: 'amy', rol: GebruikerRol.lid);

      final ontvangers = MeldingService.bepaalOntvangers(
        [ryan, amy],
        amy,
        isBulk: true,
      );

      expect(ontvangers, [ryan]);
    });

    test('beheerders met wilMeldingen krijgen een melding (single)', () {
      final ryan = _gebruiker(uid: 'ryan', rol: GebruikerRol.beheerder);
      final amy = _gebruiker(uid: 'amy', rol: GebruikerRol.lid);

      final ontvangers = MeldingService.bepaalOntvangers(
        [ryan, amy],
        amy,
        isBulk: false,
      );

      expect(ontvangers, [ryan]);
    });

    test('gewone leden krijgen nooit een melding', () {
      final ryan = _gebruiker(uid: 'ryan', rol: GebruikerRol.beheerder);
      final amy = _gebruiker(uid: 'amy', rol: GebruikerRol.lid);
      final mama = _gebruiker(uid: 'mama', rol: GebruikerRol.lid);

      final ontvangers = MeldingService.bepaalOntvangers(
        [ryan, amy, mama],
        mama,
        isBulk: true,
      );

      expect(ontvangers, [ryan]);
    });

    test('een beheerder met wilMeldingen == false krijgt niks', () {
      final ryan = _gebruiker(
        uid: 'ryan',
        rol: GebruikerRol.beheerder,
        wilMeldingen: false,
      );
      final amy = _gebruiker(uid: 'amy', rol: GebruikerRol.lid);

      expect(
        MeldingService.bepaalOntvangers([ryan, amy], amy, isBulk: true),
        isEmpty,
      );
    });

    test(
      'acteur met meldingenBulkAan == false stuurt geen bulk-melding, maar '
      'wel nog een single-melding',
      () {
        final ryan = _gebruiker(uid: 'ryan', rol: GebruikerRol.beheerder);
        final amy = _gebruiker(
          uid: 'amy',
          rol: GebruikerRol.lid,
          meldingenBulkAan: false,
        );

        expect(
          MeldingService.bepaalOntvangers([ryan, amy], amy, isBulk: true),
          isEmpty,
        );
        expect(
          MeldingService.bepaalOntvangers([ryan, amy], amy, isBulk: false),
          [ryan],
        );
      },
    );

    test(
      'acteur met meldingenSingleAan == false stuurt geen single-melding, '
      'maar wel nog een bulk-melding',
      () {
        final ryan = _gebruiker(uid: 'ryan', rol: GebruikerRol.beheerder);
        final amy = _gebruiker(
          uid: 'amy',
          rol: GebruikerRol.lid,
          meldingenSingleAan: false,
        );

        expect(
          MeldingService.bepaalOntvangers([ryan, amy], amy, isBulk: false),
          isEmpty,
        );
        expect(
          MeldingService.bepaalOntvangers([ryan, amy], amy, isBulk: true),
          [ryan],
        );
      },
    );

    test('een beheerder krijgt geen melding over zijn eigen actie', () {
      final ryan = _gebruiker(uid: 'ryan', rol: GebruikerRol.beheerder);
      final claude = _gebruiker(uid: 'claude', rol: GebruikerRol.beheerder);

      final ontvangers = MeldingService.bepaalOntvangers(
        [ryan, claude],
        ryan,
        isBulk: true,
      );

      expect(ontvangers, [claude]);
    });
  });
}
