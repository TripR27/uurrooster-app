import 'dart:typed_data';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../util/datum_util.dart';

const _maandNamen = [
  'januari',
  'februari',
  'maart',
  'april',
  'mei',
  'juni',
  'juli',
  'augustus',
  'september',
  'oktober',
  'november',
  'december',
];

/// Bouwt het gezamenlijke overzicht om tot een eenvoudige, zwart-witte
/// A4-PDF - de Android-tegenhanger van `overzicht_html.dart` (printen via
/// de browser-printdialoog werkt daar niet, zie `printen_stub.dart`).
/// Gebruikt `syncfusion_flutter_pdf` (al een dependency voor het inlezen
/// van PDF-roosters, kan ook schrijven) i.p.v. de packages `pdf`/`printing`:
/// die botsen qua `xml`-versie met `syncfusion_flutter_pdf` (zie
/// PROJECT_SPEC.md sectie 9).
Future<Uint8List> genereerOverzichtPdf({
  required DateTime maandStart,
  required List<Gebruiker> gebruikers,
  required List<Dienst> diensten,
}) async {
  final document = PdfDocument();
  try {
    final page = document.pages.add();
    final breedte = page.getClientSize().width;

    page.graphics.drawString(
      'Gezamenlijk overzicht - ${_maandNamen[maandStart.month - 1]} '
      '${maandStart.year}',
      PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold),
      bounds: Rect.fromLTWH(0, 0, breedte, 24),
    );

    final grid = PdfGrid();
    grid.columns.add(count: 1 + gebruikers.length);
    grid.headers.add(1);
    final headerRij = grid.headers[0];
    headerRij.cells[0].value = 'Dag';
    for (var i = 0; i < gebruikers.length; i++) {
      headerRij.cells[i + 1].value = gebruikers[i].naam;
    }

    final laatsteDag = DateTime(maandStart.year, maandStart.month + 1, 0).day;
    for (var dagNr = 1; dagNr <= laatsteDag; dagNr++) {
      final dag = DateTime(maandStart.year, maandStart.month, dagNr);
      final dagIso = naarIsoDatum(dag);
      final rij = grid.rows.add();
      rij.cells[0].value = naarDagLabel(dag);
      for (var i = 0; i < gebruikers.length; i++) {
        final vanDezeGebruiker = diensten.where(
          (d) => d.gebruikerId == gebruikers[i].uid && d.datum == dagIso,
        );
        rij.cells[i + 1].value = vanDezeGebruiker.isEmpty
            ? ''
            : vanDezeGebruiker
                  .map((d) => d.naarTekst(scheidingVoorOmschrijving: '\n'))
                  .join('\n');
      }
    }

    grid.style.font = PdfStandardFont(PdfFontFamily.helvetica, 10);
    grid.style.cellPadding = PdfPaddings(left: 4, right: 4, top: 4, bottom: 4);

    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 30, breedte, page.getClientSize().height - 30),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );

    return Uint8List.fromList(await document.save());
  } finally {
    document.dispose();
  }
}
