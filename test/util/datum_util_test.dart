import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/util/datum_util.dart';

void main() {
  test('dagenVanTot geeft alle dagen inclusief begin en einde', () {
    final dagen = dagenVanTot(DateTime(2026, 9, 10), DateTime(2026, 9, 15));
    expect(dagen.map(naarIsoDatum).toList(), [
      '2026-09-10',
      '2026-09-11',
      '2026-09-12',
      '2026-09-13',
      '2026-09-14',
      '2026-09-15',
    ]);
  });

  test('dagenVanTot met begin == einde geeft één dag', () {
    final dagen = dagenVanTot(DateTime(2026, 9, 10), DateTime(2026, 9, 10));
    expect(dagen, hasLength(1));
    expect(naarIsoDatum(dagen.single), '2026-09-10');
  });

  test('dagenVanTot over een maandgrens', () {
    final dagen = dagenVanTot(DateTime(2026, 1, 30), DateTime(2026, 2, 2));
    expect(dagen.map(naarIsoDatum).toList(), [
      '2026-01-30',
      '2026-01-31',
      '2026-02-01',
      '2026-02-02',
    ]);
  });
}
