import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/models/dienst.dart';
import 'package:uurrooster_app/models/gebruiker.dart';
import 'package:uurrooster_app/print/overzicht_pdf.dart';

void main() {
  test('genereerOverzichtPdf bouwt een geldig PDF-bestand', () async {
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

    final bytes = await genereerOverzichtPdf(
      maandStart: DateTime(2026, 7),
      gebruikers: gebruikers,
      diensten: diensten,
    );

    // Een geldig PDF-bestand begint altijd met de "%PDF-" header.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });

  test('genereerOverzichtPdf werkt ook zonder gebruikers/diensten', () async {
    final bytes = await genereerOverzichtPdf(
      maandStart: DateTime(2026, 2),
      gebruikers: const [],
      diensten: const [],
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
