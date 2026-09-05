import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import 'overzicht_pdf.dart';

/// Op Android (en elk ander niet-webplatform) is er geen browser om een
/// systeem-printdialoog mee te openen zoals op web (zie printen_web.dart) -
/// in plaats daarvan wordt het overzicht als PDF gegenereerd (zie
/// `overzicht_pdf.dart`) en geopend via Android's deel-scherm. Daar staat
/// op de meeste toestellen gewoon "Printen" tussen de opties, en anders kan
/// de gebruiker de PDF openen in eender welke PDF-viewer-app en die zijn
/// eigen printknop gebruiken.
Future<void> printOverzicht({
  required DateTime maandStart,
  required List<Gebruiker> gebruikers,
  required List<Dienst> diensten,
}) async {
  final bytes = await genereerOverzichtPdf(
    maandStart: maandStart,
    gebruikers: gebruikers,
    diensten: diensten,
  );

  final tijdelijkeMap = await getTemporaryDirectory();
  final maandDeel = maandStart.month.toString().padLeft(2, '0');
  final bestand = File(
    '${tijdelijkeMap.path}/rooster-${maandStart.year}-$maandDeel.pdf',
  );
  await bestand.writeAsBytes(bytes);

  await SharePlus.instance.share(
    ShareParams(files: [XFile(bestand.path)], subject: 'Gezamenlijk overzicht'),
  );
}
