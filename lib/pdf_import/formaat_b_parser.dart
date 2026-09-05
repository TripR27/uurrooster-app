import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/dienst.dart';
import 'datum_util.dart';
import 'rooster_parser.dart';

/// Herkent een uur-cel: een heel getal ("11") of een decimaal met komma
/// ("6,5" = 06:30). Amy's rooster gebruikt dit i.p.v. "HH:MM"-tekst.
final _uurPatroon = RegExp(r'^\d{1,2}(,\d+)?$');

const _maanden = [
  'jan', 'feb', 'mrt', 'apr', 'mei', 'jun',
  'jul', 'aug', 'sep', 'okt', 'nov', 'dec',
];

/// Een "vreemde" annotatie zoals "21juli" (dag+maand aan elkaar) of een
/// losstaande maand-afkorting - komt voor bij eenmalige opmerkingen (bv.
/// "RF 21juli 6 6,0") die geen echte dienst zijn. Zo'n rij slaan we over.
bool _isDatumVerwijzing(String tekst) =>
    _maanden.contains(tekst.toLowerCase()) ||
    RegExp(r'^\d+[a-zA-Z]+$').hasMatch(tekst);

/// Rooster-formaat "B": het Excel-geëxporteerde weekrooster met Amy's
/// naam (en die van haar collega's) bovenaan, en per rij een datum in
/// tekstvorm in de linkerkolom (bv. "wo 01 jul").
///
/// Per persoon staan er per dag tot 3 waarden naast elkaar: beginuur,
/// eventueel een type-code (die we negeren - behalve "N", dat betekent een
/// nachtshift), en einduur. Voorbeeld: "20 N 9" op "zo 12 jul" betekent
/// nachtshift van zondag 20u tot maandag 9u. Op vraag van Ryan wordt dit
/// als één Dienst op de zondag zelf gezet, met "Nacht" als omschrijving
/// (i.p.v. het over 2 dagen te verdelen) - dat kan later altijd nog
/// aangepast worden moest dat nodig blijken.
class FormaatBParser implements RoosterParser {
  FormaatBParser({required this.naamInRooster});

  /// Zoals de naam boven de kolom staat, bv. "Amy".
  final String naamInRooster;

  /// Alles met een x-positie kleiner dan dit staat in de datumkolom, niet
  /// in een personeelskolom.
  static const _datumKolomBreedte = 60.0;

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

      // Het bestand vermeldt zelf nergens een jaartal (enkel dag-van-de-
      // week, dagnummer en maand-afkorting) - de aanmaakdatum van het
      // PDF-bestand is de beste beschikbare gok voor het jaar.
      var jaar = document.documentInformation.creationDate.year;
      var vorigeMaand = 0;

      for (var pagina = 0; pagina < document.pages.count; pagina++) {
        final woorden = extractor
            .extractTextLines(startPageIndex: pagina, endPageIndex: pagina)
            .expand((line) => line.wordCollection)
            // Syncfusion geeft losse spaties ook als eigen "woord" terug -
            // die zijn hier nergens relevant.
            .where((w) => w.text.trim().isNotEmpty)
            .toList();

        final kolom = _vindKolom(woorden);
        if (kolom == null) continue; // deze persoon staat niet op deze pagina

        for (final rij in _vindDatumRijen(woorden)) {
          if (rij.maandNummer < vorigeMaand) jaar++;
          vorigeMaand = rij.maandNummer;
          final datum = DateTime(jaar, rij.maandNummer, rij.dagnummer);

          final dienst = _leesDienst(
            woorden: woorden,
            top: rij.top,
            kolom: kolom,
            datum: datum,
            gebruikerId: gebruikerId,
            gebruikerNaam: gebruikerNaam,
          );
          if (dienst != null) diensten.add(dienst);
        }
      }

      diensten.sort((a, b) => a.datum.compareTo(b.datum));
      return diensten;
    } finally {
      document.dispose();
    }
  }

  /// Zoekt de kolom-grenzen van [naamInRooster] in de naam-header
  /// (bovenaan de tabel): het midden tussen deze naam en de vorige/
  /// volgende naam ernaast.
  _Kolom? _vindKolom(List<TextWord> woorden) {
    // De header staat helemaal bovenaan: neem de rij namen met de
    // kleinste top-waarde op deze pagina.
    final bovensteTop = woorden.map((w) => w.bounds.top).reduce(
      (a, b) => a < b ? a : b,
    );
    final namen =
        woorden
            .where(
              (w) =>
                  (w.bounds.top - bovensteTop).abs() < 2 &&
                  RegExp(r'^[A-Z][a-zA-Z]*$').hasMatch(w.text) &&
                  w.text != 'WKT',
            )
            .toList()
          ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

    final index = namen.indexWhere((w) => w.text == naamInRooster);
    if (index == -1) return null;

    final links = index == 0
        ? _datumKolomBreedte
        : (_middenVan(namen[index - 1]) + _middenVan(namen[index])) / 2;
    final rechts = index == namen.length - 1
        ? double.infinity
        : (_middenVan(namen[index]) + _middenVan(namen[index + 1])) / 2;

    return _Kolom(links: links, rechts: rechts);
  }

  double _middenVan(TextWord woord) => (woord.bounds.left + woord.bounds.right) / 2;

  /// Groepeert alle woorden in de datumkolom per rij en herkent welke
  /// rijen een echte datum zijn (dag-afkorting + dagnummer + maand-afkorting,
  /// bv. "wo 01 jul").
  List<_DatumRij> _vindDatumRijen(List<TextWord> woorden) {
    final perTop = <double, List<TextWord>>{};
    for (final w in woorden.where((w) => w.bounds.left < _datumKolomBreedte)) {
      final top = perTop.keys.firstWhere(
        (t) => (t - w.bounds.top).abs() < 1,
        orElse: () => w.bounds.top,
      );
      (perTop[top] ??= []).add(w);
    }

    final rijen = <_DatumRij>[];
    for (final entry in perTop.entries) {
      final tekst = (entry.value..sort((a, b) => a.bounds.left.compareTo(b.bounds.left)))
          .map((w) => w.text)
          .toList();
      if (tekst.length != 3) continue;
      final maandNummer = _maandNaarNummer(tekst[2]);
      final dagnummer = int.tryParse(tekst[1]);
      if (maandNummer == null || dagnummer == null) continue;

      rijen.add(
        _DatumRij(top: entry.key, dagnummer: dagnummer, maandNummer: maandNummer),
      );
    }
    rijen.sort((a, b) => a.top.compareTo(b.top));
    return rijen;
  }

  int? _maandNaarNummer(String afkorting) {
    final index = _maanden.indexOf(afkorting.toLowerCase());
    return index == -1 ? null : index + 1;
  }

  Dienst? _leesDienst({
    required List<TextWord> woorden,
    required double top,
    required _Kolom kolom,
    required DateTime datum,
    required String gebruikerId,
    required String gebruikerNaam,
  }) {
    final tokens =
        (woorden
              .where(
                (w) =>
                    (w.bounds.top - top).abs() < 1 &&
                    w.bounds.left >= kolom.links &&
                    w.bounds.left < kolom.rechts,
              )
              .toList()
            ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left)))
        .map((w) => w.text)
        .toList();

    // Eenmalige opmerkingen die een datum vermelden (bv. "RF 21juli 6
    // 6,0") lijken oppervlakkig op een dienst maar zijn dat niet - een
    // echte type-code bevat nooit een maand-afkorting of "12juli"-achtige
    // tekst.
    if (tokens.any(_isDatumVerwijzing)) return null;

    final beginIndex = tokens.indexWhere((t) => _uurPatroon.hasMatch(t));
    if (beginIndex == -1) return null;
    final eindIndex = tokens.indexWhere(
      (t) => _uurPatroon.hasMatch(t),
      beginIndex + 1,
    );
    if (eindIndex == -1) return null;

    final beginWaarde = double.parse(tokens[beginIndex].replaceAll(',', '.'));
    final eindWaarde = double.parse(tokens[eindIndex].replaceAll(',', '.'));
    // Een echte dienst heeft nooit een gelijk begin- en einduur. Dat
    // patroon komt wel voor bij statusmarkeringen zoals "v 6 6,0" (vrij,
    // met het aantal contract-uren die dag) - geen dienst dus.
    if (beginWaarde == eindWaarde) return null;

    final typeTokens = tokens.sublist(beginIndex + 1, eindIndex);
    final isNacht = typeTokens.length == 1 && typeTokens.single == 'N';

    return Dienst(
      gebruikerId: gebruikerId,
      gebruikerNaam: gebruikerNaam,
      datum: naarIsoDatum(datum),
      startTijd: _naarUurString(beginWaarde),
      eindTijd: _naarUurString(eindWaarde),
      omschrijving: isNacht ? 'Nacht' : '',
      bron: DienstBron.pdfImport,
      aangemaaktOp: DateTime.now(),
    );
  }

  /// Zet een decimaal uur (6.5) om naar "HH:MM" ("06:30").
  String _naarUurString(double decimaalUur) {
    final uur = decimaalUur.floor();
    final minuut = ((decimaalUur - uur) * 60).round();
    return '${uur.toString().padLeft(2, '0')}:${minuut.toString().padLeft(2, '0')}';
  }
}

class _Kolom {
  _Kolom({required this.links, required this.rechts});

  final double links;
  final double rechts;
}

class _DatumRij {
  _DatumRij({required this.top, required this.dagnummer, required this.maandNummer});

  final double top;
  final int dagnummer;
  final int maandNummer;
}
