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

    test(
      'a failed outcome whose parts are each named by the surface',
      () async {
        final Body body = failsOnTrue;
        final Failed failed = await runProperty(body) as Failed;
        final ChoiceSequence sequence = failed.sequence;
        final List<Choice> choices = sequence.choices;
        final Threw run = failed.run;
        final Failure failure = run.failure;
        final Frame? frame = failure.frame;
        final ShrinkEnd end = failed.end;
        expect(choices, [Choice(1)]);
        expect(failure.type, StateError);
        expect(frame?.uri.path, endsWith('test/support/bodies.dart'));
        expect(end, ShrinkEnd.shrunk);
      },
    );

    test('a flaky outcome whose replay is a run', () async {
      final Flaky flaky = await runProperty(failsOnce()) as Flaky;
      final Run replay = flaky.replay;
      expect(replay, isA<Returned>());
      expect(replay, isNot(isA<Rejected>()));
      expect(replay, isNot(isA<Overran>()));
    });

    test('a gave-up outcome', () async {
      expect(
        await runProperty((Draw draw) => draw.assume(false)),
        isA<GaveUp>(),
      );
    });
  });
}
