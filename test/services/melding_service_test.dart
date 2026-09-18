import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/models/gebruiker.dart';
import 'package:uurrooster_app/services/melding_service.dart';

Gebruiker _gebruiker({
  required String uid,
  required GebruikerRol rol,
  bool meldingenAan = true,
  bool wilMeldingen = true,
}) {
  return Gebruiker(
    uid: uid,
    naam: uid,
    rol: rol,
    meldingenAan: meldingenAan,
    wilMeldingen: wilMeldingen,
  );
}

void main() {
  group('MeldingService.bepaalOntvangers', () {
    test('beheerders met wilMeldingen krijgen een melding', () {
      final ryan = _gebruiker(uid: 'ryan', rol: GebruikerRol.beheerder);
      final amy = _gebruiker(uid: 'amy', rol: GebruikerRol.lid);

      final ontvangers = MeldingService.bepaalOntvangers([ryan, amy], amy);

      expect(ontvangers, [ryan]);
    });

    test('gewone leden krijgen nooit een melding', () {
      final ryan = _gebruiker(uid: 'ryan', rol: GebruikerRol.beheerder);
      final amy = _gebruiker(uid: 'amy', rol: GebruikerRol.lid);
      final mama = _gebruiker(uid: 'mama', rol: GebruikerRol.lid);

      final ontvangers = MeldingService.bepaalOntvangers(
        [ryan, amy, mama],
        mama,
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

      expect(MeldingService.bepaalOntvangers([ryan, amy], amy), isEmpty);
    });

    test('acteur met meldingenAan == false stuurt niks', () {
      final ryan = _gebruiker(uid: 'ryan', rol: GebruikerRol.beheerder);
      final amy = _gebruiker(
        uid: 'amy',
        rol: GebruikerRol.lid,
        meldingenAan: false,
      );

      expect(MeldingService.bepaalOntvangers([ryan, amy], amy), isEmpty);
    });

    test('een beheerder krijgt geen melding over zijn eigen actie', () {
      final ryan = _gebruiker(uid: 'ryan', rol: GebruikerRol.beheerder);
      final claude = _gebruiker(uid: 'claude', rol: GebruikerRol.beheerder);

      final ontvangers = MeldingService.bepaalOntvangers(
        [ryan, claude],
        ryan,
      );

      expect(ontvangers, [claude]);
    });
  });
}
