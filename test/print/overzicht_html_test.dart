import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/models/dienst.dart';
import 'package:uurrooster_app/models/gebruiker.dart';
import 'package:uurrooster_app/print/overzicht_html.dart';

void main() {
  test('bouwOverzichtHtml bevat titel, kolommen en shiften', () {
    const gebruikers = [
      Gebruiker(uid: 'u1', naam: 'Ryan', rol: GebruikerRol.beheerder),
      Gebruiker(uid: 'u2', naam: 'Amy', rol: GebruikerRol.lid),
    ];
    final diensten = [
      Dienst(
        gebruikerId: 'u1',
        gebruikerNaam: 'Ryan',
        datum: '2026-07-08',
        startTijd: '08:30',
        eindTijd: '14:30',
        omschrijving: 'Werk',
        bron: DienstBron.pdfImport,
        aangemaaktOp: DateTime(2026, 7, 1),
      ),
    ];

    final html = bouwOverzichtHtml(
      maandStart: DateTime(2026, 7),
      gebruikers: gebruikers,
      diensten: diensten,
    );

    expect(html, contains('Gezamenlijk overzicht - juli 2026'));
    expect(html, contains('<th>Ryan</th>'));
    expect(html, contains('<th>Amy</th>'));
    expect(html, contains('wo 08-07'));
    expect(html, contains('08:30 - 14:30'));
    expect(html, contains('(Werk)'));
    // Een dag met 31 rijen (juli) + de header-rij.
    expect('<tr'.allMatches(html).length, 32);
  });

  test('bouwOverzichtHtml ontsnapt tekst die de gebruiker zelf typte', () {
    const gebruikers = [
      Gebruiker(uid: 'u1', naam: '<script>', rol: GebruikerRol.lid),
    ];
    final diensten = [
      Dienst(
        gebruikerId: 'u1',
        gebruikerNaam: '<script>',
        datum: '2026-02-01',
        startTijd: '09:00',
        eindTijd: '17:00',
        omschrijving: '<b>test</b>',
        bron: DienstBron.handmatig,
        aangemaaktOp: DateTime(2026, 2, 1),
      ),
    ];

    final html = bouwOverzichtHtml(
      maandStart: DateTime(2026, 2),
      gebruikers: gebruikers,
      diensten: diensten,
    );

    expect(html, isNot(contains('<script>')));
    expect(html, contains('&lt;script&gt;'));
    expect(html, contains('&lt;b&gt;test&lt;/b&gt;'));
  });
}
