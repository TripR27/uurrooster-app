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

  test('gezamenlijkOverzichtVerborgen is standaard false (F12)', () {
    const gebruiker = Gebruiker(uid: 'u1', naam: 'Amy', rol: GebruikerRol.lid);
    expect(gebruiker.gezamenlijkOverzichtVerborgen, isFalse);
  });

  test('gezamenlijkOverzichtVerborgen kan expliciet true gezet worden', () {
    const gebruiker = Gebruiker(
      uid: 'u1',
      naam: 'Amy',
      rol: GebruikerRol.lid,
      gezamenlijkOverzichtVerborgen: true,
    );
    expect(gebruiker.gezamenlijkOverzichtVerborgen, isTrue);
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

  test(
    'meldingenBulkAan, meldingenSingleAan en wilMeldingen zijn standaard '
    'true (F11/F12)',
    () {
      const gebruiker = Gebruiker(
        uid: 'u1',
        naam: 'Amy',
        rol: GebruikerRol.lid,
      );
      expect(gebruiker.meldingenBulkAan, isTrue);
      expect(gebruiker.meldingenSingleAan, isTrue);
      expect(gebruiker.wilMeldingen, isTrue);
    },
  );

  test('meldingenBulkAan en meldingenSingleAan zijn los van elkaar', () {
    const gebruiker = Gebruiker(
      uid: 'u1',
      naam: 'Amy',
      rol: GebruikerRol.lid,
      meldingenBulkAan: false,
    );
    expect(gebruiker.meldingenBulkAan, isFalse);
    expect(gebruiker.meldingenSingleAan, isTrue);
  });

  group('Gebruiker.copyWith', () {
    test('wijzigt enkel het opgegeven veld, de rest blijft behouden', () {
      const gebruiker = Gebruiker(
        uid: 'u1',
        naam: 'Amy',
        rol: GebruikerRol.lid,
        kleur: '#D8698B',
        zichtbaarInOverzicht: true,
        gezamenlijkOverzichtVerborgen: false,
        meldingenBulkAan: true,
        meldingenSingleAan: true,
        wilMeldingen: true,
      );

      final bijgewerkt = gebruiker.copyWith(zichtbaarInOverzicht: false);

      expect(bijgewerkt.zichtbaarInOverzicht, isFalse);
      // De rest overleeft - dit is precies de fout die copyWith voorkomt
      // (een handmatige reconstructie zou kleur hier stilletjes wissen).
      expect(bijgewerkt.kleur, '#D8698B');
      expect(bijgewerkt.gezamenlijkOverzichtVerborgen, isFalse);
      expect(bijgewerkt.meldingenBulkAan, isTrue);
      expect(bijgewerkt.meldingenSingleAan, isTrue);
      expect(bijgewerkt.wilMeldingen, isTrue);
      expect(bijgewerkt.uid, gebruiker.uid);
      expect(bijgewerkt.naam, gebruiker.naam);
    });

    test('kan alle vier de schakelaars los van elkaar wijzigen', () {
      const gebruiker = Gebruiker(
        uid: 'u1',
        naam: 'Ryan',
        rol: GebruikerRol.beheerder,
      );

      final bijgewerkt = gebruiker.copyWith(
        gezamenlijkOverzichtVerborgen: true,
        meldingenBulkAan: false,
        meldingenSingleAan: false,
        wilMeldingen: false,
      );

      expect(bijgewerkt.gezamenlijkOverzichtVerborgen, isTrue);
      expect(bijgewerkt.meldingenBulkAan, isFalse);
      expect(bijgewerkt.meldingenSingleAan, isFalse);
      expect(bijgewerkt.wilMeldingen, isFalse);
    });
  });
}
