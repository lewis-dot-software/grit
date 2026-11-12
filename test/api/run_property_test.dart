import 'package:grit/grit.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../support/bodies.dart';

void main() {
  group('runProperty returns', () {
    test('a passed outcome', () async {
      expect(await runProperty((Draw draw) => draw(.integer())), isA<Passed>());
    });

    test('a failed outcome', () async {
      expect(await runProperty(failsOnTrue), isA<Failed>());
    });

    test(
      'a failure read from the frame of the package it was called from',
      () async {
        // The error is thrown inside package:path, beneath this file's frame,
        // so its frame is this file's only where the call site is read here.
        final Outcome outcome = await runProperty((Draw draw) {
          if (draw(.boolean())) path.posix.fromUri(Uri.parse('http://a/b'));
        });
        expect(
          outcome,
          isA<Failed>().having(
            (Failed failed) => failed.run.failure.frame?.uri.path,
            'frame',
            endsWith('test/api/run_property_test.dart'),
          ),
        );
      },
    );

    test('a flaky outcome', () async {
      expect(await runProperty(failsOnce()), isA<Flaky>());
    });

    test('a failed outcome whose parts are each named by the surface, its '
        'shrinking ended by its step bound', () async {
      final Body body = failsOnTrue;
      // A step bound of 0 ends shrinking before its time bound is weighed,
      // so the end is the same on any machine.
      final Failed failed =
          await runProperty(body, settings: .new(shrinkSteps: 0)) as Failed;
      final ChoiceSequence sequence = failed.sequence;
      final List<Choice> choices = sequence.choices;
      final Threw run = failed.run;
      final Failure failure = run.failure;
      final Frame? frame = failure.frame;
      final ShrinkEnd end = failed.end;
      expect(choices, [Choice(1)]);
      expect(failure.type, StateError);
      expect(frame?.uri.path, endsWith('test/support/bodies.dart'));
      expect(end, ShrinkEnd.steps);
    });

    test('a flaky outcome whose replay is a run', () async {
      final Flaky flaky = await runProperty(failsOnce()) as Flaky;
      final Run replay = flaky.replay;
      expect(replay, isA<Returned>());
    });

    test('a gave-up outcome', () async {
      expect(
        await runProperty((Draw draw) => draw.assume(false)),
        isA<GaveUp>(),
      );
    });
  });
}
