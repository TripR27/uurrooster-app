import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/models/gebruiker.dart';

void main() {
  test('zichtbaarInOverzicht is standaard true (F7)', () {
    const gebruiker = Gebruiker(
      uid: 'u1',
      naam: 'Amy',
      rol: GebruikerRol.lid,
    );
    expect(gebruiker.zichtbaarInOverzicht, isTrue);
  });

  test('zichtbaarInOverzicht kan expliciet false gezet worden', () {
    const gebruiker = Gebruiker(
      uid: 'u1',
      naam: 'Claude',
      rol: GebruikerRol.beheerder,
      zichtbaarInOverzicht: false,
    );
    expect(gebruiker.zichtbaarInOverzicht, isFalse);
  });

  test('kleur is standaard null (F9) tot iemand er zelf een kiest', () {
    const gebruiker = Gebruiker(uid: 'u1', naam: 'Amy', rol: GebruikerRol.lid);
    expect(gebruiker.kleur, isNull);
  });

  test('kleur kan expliciet gezet worden', () {
    const gebruiker = Gebruiker(
      uid: 'u1',
      naam: 'Amy',
      rol: GebruikerRol.lid,
      kleur: '#D8698B',
    );
    expect(gebruiker.kleur, '#D8698B');
  });

  test('meldingenAan en wilMeldingen zijn standaard true (F11)', () {
    const gebruiker = Gebruiker(uid: 'u1', naam: 'Amy', rol: GebruikerRol.lid);
    expect(gebruiker.meldingenAan, isTrue);
    expect(gebruiker.wilMeldingen, isTrue);
  });

  group('Gebruiker.copyWith', () {
    test('wijzigt enkel het opgegeven veld, de rest blijft behouden', () {
      const gebruiker = Gebruiker(
        uid: 'u1',
        naam: 'Amy',
        rol: GebruikerRol.lid,
        kleur: '#D8698B',
        zichtbaarInOverzicht: true,
        meldingenAan: true,
        wilMeldingen: true,
      );

      final bijgewerkt = gebruiker.copyWith(zichtbaarInOverzicht: false);

      expect(bijgewerkt.zichtbaarInOverzicht, isFalse);
      // De rest overleeft - dit is precies de fout die copyWith voorkomt
      // (een handmatige reconstructie zou kleur hier stilletjes wissen).
      expect(bijgewerkt.kleur, '#D8698B');
      expect(bijgewerkt.meldingenAan, isTrue);
      expect(bijgewerkt.wilMeldingen, isTrue);
      expect(bijgewerkt.uid, gebruiker.uid);
      expect(bijgewerkt.naam, gebruiker.naam);
    });

    test('kan meldingenAan en wilMeldingen los van elkaar wijzigen', () {
      const gebruiker = Gebruiker(
        uid: 'u1',
        naam: 'Ryan',
        rol: GebruikerRol.beheerder,
      );

      final bijgewerkt = gebruiker.copyWith(
        meldingenAan: false,
        wilMeldingen: false,
      );

      expect(bijgewerkt.meldingenAan, isFalse);
      expect(bijgewerkt.wilMeldingen, isFalse);
    });
  });
}
