import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/outcomes.dart';

void main() {
  group('on grit, over larger inputs', () {
    property('An outcome\'s warnings cannot be changed by whoever reads '
        'them.', (Draw draw) {
      final Outcome outcome = draw(outcomes);
      final List<Warning> read = outcome.warnings;
      final List<Warning> before = [...read];
      final Warning warning = UnreadableStored(NotAToken());
      final List<void Function()> changes = [
        () => read.add(warning),
        () => read.insert(0, warning),
        () => read.clear(),
        if (read.isNotEmpty) ...[
          () => read[0] = warning,
          () => read.removeLast(),
          () => read.sort((_, _) => 0),
        ],
      ];
      for (final void Function() change in changes) {
        expect(change, throwsUnsupportedError);
      }
      expect(outcome.warnings, before);
    });
  });

  test('the warnings an outcome was handed, changed later, leave its own '
      'as they were', () {
    final List<Warning> handed = [UnreadableStored(NotAToken())];
    final Passed passed = .new(runs: 1, warnings: handed);
    handed.clear();
    expect(passed.warnings, [isA<UnreadableStored>()]);
  });
}
