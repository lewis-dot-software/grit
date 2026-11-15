import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/bodies.dart';

/// A [TestFailure] whose message starts with [start].
Matcher _failure(String start) => throwsA(
  isA<TestFailure>().having(
    (TestFailure failure) => failure.message,
    'message',
    startsWith(start),
  ),
);

void main() {
  group('forAll', () {
    test('returns on a passed outcome', () async {
      await forAll((Draw draw) => draw(.integer()));
    });

    test('fails the test on a failed outcome', () {
      expect(forAll(failsOnTrue), _failure('The property failed.'));
    });

    test('fails the test on a flaky outcome', () {
      expect(forAll(failsOnce()), _failure('The property is flaky'));
    });

    test('fails the test on a reproduced outcome', () {
      expect(
        forAll(failsOnTrue, settings: .new(replay: 'grit1:1')),
        _failure('The property failed on the case its replay token names'),
      );
    });

    test('fails the test on a not-reproduced outcome', () {
      expect(
        forAll(failsOnTrue, settings: .new(replay: 'grit1:0')),
        _failure('The replay token no longer reproduces a failure'),
      );
    });

    test('fails the test on grit\'s own error inside a draw, as it was '
        'thrown, in place of an outcome', () {
      expect(
        forAll(
          (Draw draw) =>
              draw(.build((Draw draw) => draw(.integer(min: 1, max: 0)))),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            'The minimum 1 is above the maximum 0',
          ),
        ),
      );
    });

    test('fails the test on a gave-up outcome', () {
      expect(
        forAll((Draw draw) => draw.assume(false)),
        _failure('The property gave up'),
      );
    });
  });
}
