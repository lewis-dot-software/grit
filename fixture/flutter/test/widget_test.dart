import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grit/grit.dart';

void main() {
  testWidgets('forAll searches inside a testWidgets', (
    WidgetTester tester,
  ) async {
    await forAll((Draw draw) async {
      final int count = draw(.integer(min: 0, max: 1000), label: 'count');
      await tester.pumpWidget(Text('$count', textDirection: .ltr));
      expect(find.text('$count'), findsOneWidget);
    }, settings: .new(runs: 20));
  });

  property('a property declares a test beside flutter_test', (Draw draw) {
    final List<bool> flags = draw(.list(.boolean()));
    expect(
      flags.where((bool flag) => flag).length,
      lessThanOrEqualTo(flags.length),
    );
  });
}
