import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dienst.dart';
import '../util/datum_util.dart';

/// Eén schooldag zoals uit WebUntis afgeleid: van het vroegste lesbegin tot
/// het laatste leseinde. Ryan wil enkel weten "van wanneer tot wanneer ben
/// ik die dag op school", niet welke lessen (zie PROJECT_SPEC.md F4).
class Schooldag {
  const Schooldag({
    required this.datum,
    required this.start,
    required this.eind,
  });

  final DateTime datum; // op middernacht
  final String start; // "09:00"
  final String eind; // "15:00"
}

class SchoolroosterFout implements Exception {
  SchoolroosterFout(this.bericht);
  final String bericht;
  @override
  String toString() => bericht;
}

/// Haalt het schoolrooster op uit de **publieke, anonieme** WebUntis-API van
/// AP Hogeschool (school `ap`) - geen login nodig. Zie PROJECT_SPEC.md F4
/// voor de reverse-engineering en de endpoints.
class SchoolroosterService {
  SchoolroosterService._();

  static const _weekData =
      'https://ap.webuntis.com/WebUntis/api/public/timetable/weekly/data';

  /// Alle schooldagen van [maand]/[jaar] voor klas [klasId], met enkel de
  /// lessen die Ryan effectief volgt: de vaste vakken + zijn eigen minor
  /// ([minorVak], bv. `MDI_IT_PROJIXREA`), niet de andere keuzevakken.
  ///
  /// Doet één request per week die de maand raakt. Geeft een lege lijst
  /// terug als er (nog) geen rooster gepubliceerd is voor die maand.
  static Future<List<Schooldag>> haalMaand({
    required int klasId,
    required String minorVak,
    required int jaar,
    required int maand,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    try {
      final eerste = DateTime(jaar, maand, 1);
      final laatste = DateTime(jaar, maand + 1, 0);
      var maandag = eerste.subtract(Duration(days: eerste.weekday - 1));

      final perDatum = <DateTime, Schooldag>{};
      while (!maandag.isAfter(laatste)) {
        final json = await _haalWeek(c, klasId, maandag);
        final dagen = leesWeekrooster(
          json,
          klasId: klasId,
          minorVak: minorVak,
        );
        for (final dag in dagen) {
          if (dag.datum.year == jaar && dag.datum.month == maand) {
            perDatum[dag.datum] = dag;
          }
        }
        // Via de constructor i.p.v. Duration(days: 7): dat laatste kan rond
        // een zomer-/wintertijdwissel een dag verschuiven.
        maandag = DateTime(maandag.year, maandag.month, maandag.day + 7);
      }

      return perDatum.values.toList()
        ..sort((a, b) => a.datum.compareTo(b.datum));
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<Map<String, dynamic>> _haalWeek(
    http.Client c,
    int klasId,
    DateTime maandag,
  ) async {
    final d =
        '${maandag.year}-${_twee(maandag.month)}-${_twee(maandag.day)}';
    final uri = Uri.parse(
      '$_weekData?elementType=1&elementId=$klasId&date=$d&formatId=1',
    );
    final http.Response r;
    try {
      r = await c.get(uri, headers: const {'Accept': 'application/json'});
    } catch (e) {
      throw SchoolroosterFout(
        'Kon WebUntis niet bereiken. Werkt de app op Android? '
        '(De webversie kan dit door browserbeveiliging niet.) Details: $e',
      );
    }
    if (r.statusCode != 200) {
      throw SchoolroosterFout('WebUntis antwoordde met status ${r.statusCode}.');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

/// Zet één WebUntis-week (JSON zoals de publieke API teruggeeft) om naar een
/// lijst [Schooldag]. Puur, zonder netwerk - apart testbaar.
///
/// Filter:
/// - geannuleerde lesblokken tellen niet mee;
/// - andere keuzevakken/minors (`MDI_IT_PROJ*` die niet [minorVak] zijn)
///   tellen niet mee - de rest wel (Ryan volgt naast Mixed Reality geen
///   andere keuzevakken, zie PROJECT_SPEC.md F4);
/// - per dag: vroegste `startTime` → laatste `endTime`.
List<Schooldag> leesWeekrooster(
  Map<String, dynamic> json, {
  required int klasId,
  required String minorVak,
}) {
  final data =
      ((json['data'] as Map?)?['result'] as Map?)?['data'] as Map<String, dynamic>?;
  if (data == null) return const [];

  final perioden =
      (data['elementPeriods'] as Map?)?['$klasId'] as List? ?? const [];

  final vakNaam = <int, String>{};
  for (final e in (data['elements'] as List? ?? const [])) {
    if (e is Map && e['type'] == 3 && e['id'] != null) {
      vakNaam[(e['id'] as num).toInt()] = (e['name'] as String?) ?? '';
    }
  }

  final minor = _normaliseerVak(minorVak);

  final start = <DateTime, int>{};
  final eind = <DateTime, int>{};

  for (final p in perioden) {
    if (p is! Map) continue;
    if (_isGeannuleerd(p)) continue;

    final vakken = [
      for (final e in (p['elements'] as List? ?? const []))
        if (e is Map && e['type'] == 3 && e['id'] != null)
          vakNaam[(e['id'] as num).toInt()] ?? '',
    ];
    if (vakken.any((v) => _isAndereMinor(v, minor))) continue;

    final datum = _leesDatum(p['date']);
    final s = (p['startTime'] as num?)?.toInt();
    final e = (p['endTime'] as num?)?.toInt();
    if (datum == null || s == null || e == null) continue;

    start.update(datum, (v) => s < v ? s : v, ifAbsent: () => s);
    eind.update(datum, (v) => e > v ? e : v, ifAbsent: () => e);
  }

  final dagen = start.keys.toList()..sort();
  return [
    for (final d in dagen)
      Schooldag(datum: d, start: _hhmm(start[d]!), eind: _hhmm(eind[d]!)),
  ];
}

/// Maakt van een [Schooldag] een op te slaan [Dienst] met `bron:
/// schoolrooster` en omschrijving "School".
Dienst schooldagNaarDienst(
  Schooldag dag, {
  required String gebruikerId,
  required String gebruikerNaam,
}) {
  return Dienst(
    gebruikerId: gebruikerId,
    gebruikerNaam: gebruikerNaam,
    datum: naarIsoDatum(dag.datum),
    startTijd: dag.start,
    eindTijd: dag.eind,
    omschrijving: 'School',
    bron: DienstBron.schoolrooster,
    aangemaaktOp: DateTime.now(),
  );
}

String _twee(int n) => n.toString().padLeft(2, '0');

String _hhmm(int t) =>
    '${(t ~/ 100).toString().padLeft(2, '0')}:${(t % 100).toString().padLeft(2, '0')}';

DateTime? _leesDatum(dynamic raw) {
  final n = (raw as num?)?.toInt();
  if (n == null || n < 10000000) return null;
  return DateTime(n ~/ 10000, (n ~/ 100) % 100, n % 100);
}

/// "MDI_IT_PROJIXREA", "PROJIXREA" en "projixrea" tellen als hetzelfde vak,
/// zodat het niet uitmaakt hoe de minor precies in het profiel staat.
String _normaliseerVak(String v) =>
    v.toUpperCase().replaceAll('MDI_IT_', '').trim();

/// Een keuzevak/minor (`MDI_IT_PROJ*`) dat niet de minor van Ryan is.
bool _isAndereMinor(String vak, String minorGenormaliseerd) {
  final n = _normaliseerVak(vak);
  return n.startsWith('PROJ') && n != minorGenormaliseerd;
}

bool _isGeannuleerd(Map p) {
  final cs = (p['cellState'] as String?)?.toUpperCase() ?? '';
  if (cs.contains('CANCEL')) return true;
  final code = p['code'];
  if (code is String && code.toLowerCase().contains('cancel')) return true;
  final is_ = p['is'];
  if (is_ is Map && is_['cancelled'] == true) return true;
  return false;
}
