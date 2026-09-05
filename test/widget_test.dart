import 'package:flutter_test/flutter_test.dart';

import 'package:uurrooster_app/main.dart';

void main() {
  testWidgets('HomePage toont titel', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Gezinsrooster'), findsOneWidget);
  });
}
