import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grit/grit.dart';

/// How many runs must return for each search here to pass.
const int _runs = 20;

void main() {
  testWidgets('forAll searches inside a testWidgets', (
    WidgetTester tester,
  ) async {
    int runs = 0;
    await forAll((Draw draw) async {
      runs++;
      final int count = draw(.integer(min: 0, max: 1000), label: 'count');
      await tester.pumpWidget(Text('$count', textDirection: .ltr));
      expect(find.text('$count'), findsOneWidget);
    }, settings: .new(runs: _runs));
    expect(runs, greaterThanOrEqualTo(_runs));
  });

  group('a property', () {
    int runs = 0;
    // A property's test cannot read its own body's runs, so the group's
    // teardown reads them once it has run.
    tearDownAll(() => expect(runs, greaterThanOrEqualTo(_runs)));

    property('declares a test beside flutter_test, whose body grit runs', (
      Draw draw,
    ) {
      runs++;
      final List<bool> flags = draw(.list(.boolean()));
      expect(
        flags.where((bool flag) => flag).length,
        lessThanOrEqualTo(flags.length),
      );
    }, settings: .new(runs: _runs));
  });
}
