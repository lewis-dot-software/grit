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

    test('fails the test on a gave-up outcome', () {
      expect(
        forAll((Draw draw) => draw.assume(false)),
        _failure('The property gave up'),
      );
    });
  });
}
