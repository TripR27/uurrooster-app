// Wegwerp-check tegen de ECHTE WebUntis-API (draait op de Dart VM, geen
// CORS). Niet in de gewone testset - draai handmatig:
//   flutter test test/school/_live_check.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/school/schoolrooster_service.dart';

void main() {
  test('haalMaand tegen live WebUntis (nov 2025, 3ITSOF1)', () async {
    final dagen = await SchoolroosterService.haalMaand(
      klasId: 3905,
      minorVak: 'MDI_IT_PROJIXREA',
      jaar: 2025,
      maand: 11,
    );
    for (final d in dagen) {
      // ignore: avoid_print
      print('${d.datum.toIso8601String().split('T').first}  ${d.start} - ${d.eind}');
    }
    expect(dagen, isNotEmpty);
  });
}
