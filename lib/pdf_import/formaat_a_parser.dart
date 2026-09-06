import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/dienst.dart';
import '../util/datum_util.dart';
import 'rooster_parser.dart';

/// Herkent een tijd-cel zoals "08:30".
final _tijdPatroon = RegExp(r'^\d{2}:\d{2}$');

/// Herkent "Periode: 1-7-2026 tot 1-8-2026" (we gebruiken enkel de
/// startdatum, als basis-maand/jaar voor de dag-kolommen).
final _periodePatroon = RegExp(r'Periode:\s*(\d{1,2})-(\d{1,2})-(\d{4})');

/// Herkent voettekst-lijnen onderaan elke pagina (paginanummer "1/2",
/// datum+tijd van afdrukken, "Dienstrooster") die geen deel uitmaken van
/// de rooster-tabel zelf en dus genegeerd moeten worden.
bool _isVoettekst(String tekst) {
  final t = tekst.trim();
  return t.contains('Dienstrooster') ||
      RegExp(r'^\d+\s*/\s*\d+$').hasMatch(t) ||
      RegExp(r'^\d{1,2}-\d{1,2}-\d{4}').hasMatch(t);
}

/// Eén dag-kolom in de tabel: de horizontale positie (om cellen aan deze
/// kolom te koppelen) + de effectieve kalenderdatum.
class _DagKolom {
  _DagKolom({required this.middenX, required this.datum});

  final double middenX;
  final DateTime datum;
}

/// Rooster-formaat "A": het "Dienstrooster"-PDF van de
/// keuken/afwaskeuken-roostergroep (Ryan en mama gebruiken dit formaat,
/// zie PROJECT_SPEC.md §6).
///
/// Het is een horizontale tabel: bovenaan per kolom een dag-van-de-week +
/// datumnummer, links per rij een personeelsnaam. Een cel is ofwel leeg
/// (niet werken), begint met "FDrec" (ook niet werken - recuperatiedag),
/// of heeft een code (die we negeren, bv. "CV4") gevolgd door een begin-
/// en einduur.
///
/// We werken met de x/y-positie van elk stukje tekst (Syncfusion geeft dat
/// mee per tekstlijn) i.p.v. de platte tekst, want de tabel-layout is
/// enkel via positie terug te vinden.
class FormaatAParser implements RoosterParser {
  FormaatAParser({required this.naamInRooster});

  /// Zoals de naam letterlijk in de PDF staat, bv. "Wyters, Ryan". Daarmee
  /// zoeken we de juiste rij op (elke persoon staat met dezelfde
  /// tabel-layout in dit PDF-formaat, enkel de rij verschilt).
  final String naamInRooster;

  /// Alles met een x-positie kleiner dan dit staat in de naamkolom, niet
  /// in een dag-kolom.
  static const _naamKolomBreedte = 60.0;

  @override
  List<Dienst> parse(
    Uint8List pdfBytes, {
    required String gebruikerId,
    required String gebruikerNaam,
  }) {
    final document = PdfDocument(inputBytes: pdfBytes);
    try {
      final extractor = PdfTextExtractor(document);
      final diensten = <Dienst>[];
      DateTime? periodeStart;

      for (var pagina = 0; pagina < document.pages.count; pagina++) {
        final lines = extractor
            .extractTextLines(startPageIndex: pagina, endPageIndex: pagina)
            .where((line) => !_isVoettekst(line.text))
            .toList();

        // "Periode: ..." staat enkel op de eerste pagina, maar geldt voor
        // het hele rooster.
        periodeStart ??= _vindPeriodeStart(lines);
        if (periodeStart == null) continue;

        final headerLijn = _vindDagNummerHeader(lines);
        if (headerLijn == null) continue;
        final kolommen = _naarDagKolommen(headerLijn, periodeStart);

        final rijLijnen = _vindRijLijnen(lines, headerLijn);
        // deze persoon staat niet op deze pagina
        if (rijLijnen == null) continue;

        diensten.addAll(
          _leesDienstenUitRij(
            rijLijnen,
            kolommen,
            gebruikerId: gebruikerId,
            gebruikerNaam: gebruikerNaam,
          ),
        );
      }

      return diensten;
    } finally {
      document.dispose();
    }
  }

  DateTime? _vindPeriodeStart(List<TextLine> lines) {
    for (final line in lines) {
      final match = _periodePatroon.firstMatch(line.text);
      if (match != null) {
        return DateTime(
          int.parse(match.group(3)!),
          int.parse(match.group(2)!),
          int.parse(match.group(1)!),
        );
      }
    }
    return null;
  }

  /// Zoekt de header-lijn met alle dagnummers (1 t.e.m. 31): de lijn met de
  /// meeste woorden die zuiver een dagnummer zijn.
  TextLine? _vindDagNummerHeader(List<TextLine> lines) {
    TextLine? headerLijn;
    var meesteMatches = 0;
    for (final line in lines) {
      final aantalDagnummers = line.wordCollection
          .where((w) => RegExp(r'^\d{1,2}$').hasMatch(w.text.trim()))
          .length;
      if (aantalDagnummers > meesteMatches) {
        meesteMatches = aantalDagnummers;
        headerLijn = line;
      }
    }
    return meesteMatches >= 5 ? headerLijn : null;
  }

  /// Zet de dagnummer-header om naar effectieve kalenderdatums. Een
  /// dagnummer dat kleiner is dan (of gelijk aan) het vorige betekent dat
  /// de tabel naar de volgende maand is overgegaan.
  List<_DagKolom> _naarDagKolommen(TextLine headerLijn, DateTime periodeStart) {
    final kolommen = <_DagKolom>[];
    var maand = periodeStart.month;
    var jaar = periodeStart.year;
    int? vorigDagnummer;

    final woorden = List<TextWord>.from(headerLijn.wordCollection)
      ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

    for (final woord in woorden) {
      final dagnummer = int.tryParse(woord.text.trim());
      if (dagnummer == null) continue;

      if (vorigDagnummer != null && dagnummer <= vorigDagnummer) {
        maand++;
        if (maand > 12) {
          maand = 1;
          jaar++;
        }
      }
      vorigDagnummer = dagnummer;

      kolommen.add(
        _DagKolom(
          middenX: (woord.bounds.left + woord.bounds.right) / 2,
          datum: DateTime(jaar, maand, dagnummer),
        ),
      );
    }
    return kolommen;
  }

  /// Zoekt alle tekstlijnen die bij de rij van [naamInRooster] horen.
  ///
  /// Een naam staat niet noodzakelijk bovenaan zijn eigen rij (soms staat
  /// de code-lijn er net boven, bv. wanneer de vorige rij weinig lijnen
  /// nodig had) - de naam staat ergens verticaal "in het midden" van de
  /// 3 à 5 tekstlijnen van die rij. Daarom bepalen we de grenzen van een
  /// rij als het midden tussen deze naam en de vorige/volgende naam in de
  /// naamkolom (herkenbaar aan een komma), met de laatste header-lijn als
  /// bovengrens voor de allereerste rij op een pagina.
  List<TextLine>? _vindRijLijnen(List<TextLine> lines, TextLine headerLijn) {
    final genormaliseerdeNaam = _normaliseer(naamInRooster);

    final naamLijnen =
        lines
            .where(
              (l) => l.bounds.left < _naamKolomBreedte && l.text.contains(','),
            )
            .toList()
          ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

    final naamIndex = naamLijnen.indexWhere(
      (line) => _normaliseer(line.text) == genormaliseerdeNaam,
    );
    if (naamIndex == -1) return null;

    final naamTop = naamLijnen[naamIndex].bounds.top;
    final ondergrens = naamIndex == 0
        ? headerLijn.bounds.bottom
        : (naamLijnen[naamIndex - 1].bounds.top + naamTop) / 2;
    final bovengrens = naamIndex == naamLijnen.length - 1
        ? double.infinity
        : (naamTop + naamLijnen[naamIndex + 1].bounds.top) / 2;

    return lines
        .where(
          (line) =>
              line.bounds.top > ondergrens &&
              line.bounds.top < bovengrens &&
              line.bounds.left >= _naamKolomBreedte,
        )
        .toList();
  }

  List<Dienst> _leesDienstenUitRij(
    List<TextLine> rijLijnen,
    List<_DagKolom> kolommen, {
    required String gebruikerId,
    required String gebruikerNaam,
  }) {
    // Groepeer elke tekstlijn bij de dag-kolom waar ze het dichtst bij ligt.
    final perKolom = <_DagKolom, List<TextLine>>{};
    for (final line in rijLijnen) {
      final middenX = (line.bounds.left + line.bounds.right) / 2;
      final kolom = kolommen.reduce(
        (a, b) =>
            (a.middenX - middenX).abs() < (b.middenX - middenX).abs() ? a : b,
      );
      (perKolom[kolom] ??= []).add(line);
    }

    final diensten = <Dienst>[];
    for (final entry in perKolom.entries) {
      final cellen = entry.value
        ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

      // Een werkdag heeft altijd: [code, begintijd, eindtijd, ...]. Alles
      // anders (leeg, "FDrec" + "up", een code zonder tijden) is een dag
      // waarop niet gewerkt wordt, en die slaan we gewoon over.
      if (cellen.length < 3) continue;
      final begin = cellen[1].text.trim();
      final eind = cellen[2].text.trim();
      if (!_tijdPatroon.hasMatch(begin) || !_tijdPatroon.hasMatch(eind)) {
        continue;
      }

      diensten.add(
        Dienst(
          gebruikerId: gebruikerId,
          gebruikerNaam: gebruikerNaam,
          datum: naarIsoDatum(entry.key.datum),
          startTijd: begin,
          eindTijd: eind,
          // Formaat A kent geen nachtshift-onderscheid zoals Formaat B - hier
          // is elke gevonden shift gewoon een werkdienst.
          omschrijving: 'Werk',
          bron: DienstBron.pdfImport,
          aangemaaktOp: DateTime.now(),
        ),
      );
    }

    diensten.sort((a, b) => a.datum.compareTo(b.datum));
    return diensten;
  }

  String _normaliseer(String tekst) =>
      tekst.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}
