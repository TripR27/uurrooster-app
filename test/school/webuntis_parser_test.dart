import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/models/dienst.dart';
import 'package:uurrooster_app/school/schoolrooster_service.dart';

Map<String, dynamic> _fixture(String naam) {
  final bestand = File('test/school/fixtures/$naam');
  return jsonDecode(bestand.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('leesWeekrooster (echte WebUntis-week 3ITSOF1, 3-9 nov 2025)', () {
    final json = _fixture('week_2025-11-03.json');

    test('per schooldag het vroegste begin tot het laatste einde', () {
      final dagen = leesWeekrooster(
        json,
        klasId: 3905,
        minorVak: 'MDI_IT_PROJIXREA',
      );

      final gezien = {
        for (final d in dagen)
          '${d.datum.year}-${d.datum.month.toString().padLeft(2, '0')}-'
                  '${d.datum.day.toString().padLeft(2, '0')}':
              '${d.start}-${d.eind}',
      };

      // Ma: enkel Mixed Reality (de andere minors PROJMAKER/PROJROB/PROJSTUP
      // vallen weg), 09:00 -> 15:00.
      expect(gezien['2025-11-03'], '09:00-15:00');
      // Di: APPSOFPR + ITPROF + SWTR -> 09:00 tot 18:00.
      expect(gezien['2025-11-04'], '09:00-18:00');
      expect(gezien['2025-11-05'], '09:00-16:00');
      // Do: MOBDEV + DTFND; de PROJMAKER-blokken van 16-18u tellen niet mee.
      expect(gezien['2025-11-06'], '09:00-16:00');
      expect(gezien['2025-11-07'], '09:00-13:00');
      expect(dagen, hasLength(5));
    });

    test('de minor-notatie mag ook zonder "MDI_IT_"-prefix', () {
      final a = leesWeekrooster(json, klasId: 3905, minorVak: 'MDI_IT_PROJIXREA');
      final b = leesWeekrooster(json, klasId: 3905, minorVak: 'PROJIXREA');
      expect(
        b.map((d) => '${d.start}-${d.eind}').toList(),
        a.map((d) => '${d.start}-${d.eind}').toList(),
      );
    });

    test('met een andere minor gekozen verschuift het maandagvenster', () {
      // Met PROJMAKER als "eigen" minor tellen Mixed Reality, Robotics en
      // Start up niet mee; enkel PROJMAKER (ma 14:00-17:00).
      final dagen = leesWeekrooster(
        json,
        klasId: 3905,
        minorVak: 'MDI_IT_PROJMAKER',
      );
      final ma = dagen.firstWhere((d) => d.datum.day == 3);
      expect('${ma.start}-${ma.eind}', '14:00-17:00');
    });

    test('lege of onbekende JSON geeft een lege lijst', () {
      expect(leesWeekrooster(const {}, klasId: 3905, minorVak: 'X'), isEmpty);
      expect(
        leesWeekrooster(const {
          'data': {
            'result': {
              'data': {'elementPeriods': {}, 'elements': []},
            },
          },
        }, klasId: 3905, minorVak: 'X'),
        isEmpty,
      );
    });

    test('geannuleerde lesblokken tellen niet mee', () {
      final metCancel = {
        'data': {
          'result': {
            'data': {
              'elementPeriods': {
                '3905': [
                  {
                    'date': 20251103,
                    'startTime': 800,
                    'endTime': 900,
                    'cellState': 'CANCEL',
                    'elements': [
                      {'type': 3, 'id': 1},
                    ],
                  },
                  {
                    'date': 20251103,
                    'startTime': 1000,
                    'endTime': 1100,
                    'cellState': 'STANDARD',
                    'elements': [
                      {'type': 3, 'id': 1},
                    ],
                  },
                ],
              },
              'elements': [
                {'type': 3, 'id': 1, 'name': 'MDI_IT_DTFND'},
              ],
            },
          },
        },
      };
      final dagen = leesWeekrooster(
        metCancel,
        klasId: 3905,
        minorVak: 'MDI_IT_PROJIXREA',
      );
      expect(dagen, hasLength(1));
      expect(dagen.single.start, '10:00'); // het 08:00-blok is geannuleerd
    });
  });

  test('schooldagNaarDienst zet de juiste bron en omschrijving', () {
    final d = schooldagNaarDienst(
      Schooldag(datum: DateTime(2025, 11, 3), start: '09:00', eind: '15:00'),
      gebruikerId: 'u1',
      gebruikerNaam: 'Ryan',
    );
    expect(d.bron, DienstBron.schoolrooster);
    expect(d.omschrijving, 'School');
    expect(d.datum, '2025-11-03');
    expect(d.startTijd, '09:00');
    expect(d.eindTijd, '15:00');
  });
}
