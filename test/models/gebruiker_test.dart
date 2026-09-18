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
}
