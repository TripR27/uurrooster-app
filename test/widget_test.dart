import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uurrooster_app/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen toont e-mail- en wachtwoordveld', (
    WidgetTester tester,
  ) async {
    // We testen hier bewust enkel LoginScreen (niet MyApp/AuthGate): AuthGate
    // heeft een echte Firebase-verbinding nodig, wat niet beschikbaar is in
    // een widget-test zonder mocking.
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('E-mailadres'), findsOneWidget);
    expect(find.text('Wachtwoord'), findsOneWidget);
    // "Inloggen" komt twee keer voor (AppBar-titel + knoptekst), dus zoeken
    // we specifiek naar de knop.
    final inlogKnop = find.widgetWithText(FilledButton, 'Inloggen');
    expect(inlogKnop, findsOneWidget);

    // Op "Inloggen" drukken zonder iets in te vullen moet validatiefouten
    // tonen, zonder dat Firebase aangesproken wordt.
    await tester.tap(inlogKnop);
    await tester.pump();

    expect(find.text('Vul je e-mailadres in.'), findsOneWidget);
    expect(find.text('Vul je wachtwoord in.'), findsOneWidget);
  });
}
