import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import 'overzicht_html.dart';

/// Print het gezamenlijke overzicht rechtstreeks af via de
/// systeem-printdialoog van de browser: laadt de HTML (zie
/// `overzicht_html.dart`) in een onzichtbare iframe en roept daarop
/// `window.print()` aan - de standaardtruc om iets anders dan de huidige
/// pagina te printen zonder ernaartoe te moeten navigeren.
Future<void> printOverzicht({
  required DateTime maandStart,
  required List<Gebruiker> gebruikers,
  required List<Dienst> diensten,
}) async {
  final htmlContent = bouwOverzichtHtml(
    maandStart: maandStart,
    gebruikers: gebruikers,
    diensten: diensten,
  );

  final iframe = web.HTMLIFrameElement()
    ..style.position = 'fixed'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = 'none';
  web.document.body!.append(iframe);

  final venster = iframe.contentWindow!;
  final document = venster.document;
  document.open();
  document.write(htmlContent.toJS);
  document.close();

  venster.focus();
  venster.print();

  // De iframe pas na de printdialoog opruimen - meteen verwijderen zou het
  // printen zelf kunnen afbreken.
  Future.delayed(const Duration(seconds: 1), () => iframe.remove());
}
