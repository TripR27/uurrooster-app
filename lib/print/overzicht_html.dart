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

const _stijl = '''
  body { font-family: Arial, Helvetica, sans-serif; color: #111; margin: 24px; }
  h1 { font-size: 20px; margin-bottom: 16px; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #999; padding: 5px 8px; font-size: 14px;
    text-align: left; white-space: pre-line; vertical-align: top; }
  th, td.dag { background: #e3e3e3; font-weight: bold; }
  @media print { body { margin: 0; } }
''';

/// Bouwt het gezamenlijke overzicht (zie BeheerOverzichtScreen) om tot een
/// zelfstandige HTML-pagina om rechtstreeks af te drukken (zie
/// `lib/print/printen.dart`) - titel bovenaan, daaronder een tabel met 1
/// kolom per gezinslid en 1 rij per dag van de maand, met de naam-/
/// dag-kolommen in een lichtgrijs vakje + dikkere tekst voor wat meer
/// onderscheid (zie PROJECT_SPEC.md sectie 9).
String bouwOverzichtHtml({
  required DateTime maandStart,
  required List<Gebruiker> gebruikers,
  required List<Dienst> diensten,
}) {
  final laatsteDag = DateTime(maandStart.year, maandStart.month + 1, 0).day;
  final buffer = StringBuffer()
    ..writeln('<!doctype html><html><head><meta charset="utf-8">')
    ..writeln('<title>Gezamenlijk overzicht</title>')
    ..writeln('<style>$_stijl</style>')
    ..writeln('</head><body>')
    ..writeln(
      '<h1>Gezamenlijk overzicht - '
      '${_maandNamen[maandStart.month - 1]} ${maandStart.year}</h1>',
    )
    ..writeln('<table><tr><th>Dag</th>');
  for (final gebruiker in gebruikers) {
    buffer.writeln('<th>${_escape(gebruiker.naam)}</th>');
  }
  buffer.writeln('</tr>');

  for (var dagNr = 1; dagNr <= laatsteDag; dagNr++) {
    final dag = DateTime(maandStart.year, maandStart.month, dagNr);
    final dagIso = naarIsoDatum(dag);
    buffer.writeln('<tr><td class="dag">${_escape(naarDagLabel(dag))}</td>');
    for (final gebruiker in gebruikers) {
      final vanDezeGebruiker = diensten.where(
        (d) => d.gebruikerId == gebruiker.uid && d.datum == dagIso,
      );
      final inhoud = vanDezeGebruiker.isEmpty
          ? ''
          : vanDezeGebruiker
                .map(
                  (d) => _escape(d.naarTekst(scheidingVoorOmschrijving: '\n')),
                )
                .join('\n');
      buffer.writeln('<td>$inhoud</td>');
    }
    buffer.writeln('</tr>');
  }
  buffer.writeln('</table></body></html>');
  return buffer.toString();
}

/// Ontsnapt tekst die de gebruiker zelf typte (naam, omschrijving) voor
/// gebruik in HTML - anders kan bv. een omschrijving met "<" de tabel-opmaak
/// breken.
String _escape(String tekst) => tekst
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
