import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Print [htmlContent] rechtstreeks af via de systeem-printdialoog van de
/// browser: laadt de HTML in een onzichtbare iframe en roept daarop
/// `window.print()` aan - de standaardtruc om iets anders dan de huidige
/// pagina te printen zonder ernaartoe te moeten navigeren.
void printHtml(String htmlContent) {
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
