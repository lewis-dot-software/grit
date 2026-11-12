import 'package:grit/grit.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Settings whose time never bounds shrinking, so each failing case shrinks
/// to its smallest on any machine.
final Settings _settings = .new(seed: 1, shrinkTime: const .new(days: 1));

/// The properties grit's own suite runs through `dart test`, each named for
/// the outcome it comes to.
void main() {
  property('fails', (Draw draw) {
    final List<int> xs = draw(.list(.integer(min: 0, max: 100)), label: 'xs');
    draw.note('sum ${xs.fold(0, (int sum, int x) => sum + x)}');
    expect(xs.fold(0, (int sum, int x) => sum + x), lessThan(10));
  }, settings: _settings);

  property('passes', (Draw draw) {
    final int x = draw(.integer());
    expect(x + 0, x);
  }, settings: _settings);

  property('gives up', (Draw draw) {
    draw.assume(false);
  }, settings: _settings);

  bool failed = false;
  property('is flaky', (Draw draw) {
    if (failed) {
      // Thrown inside package:path, so the report names this file's frame
      // only where the call site was read at the declaration.
      path.posix.fromUri(Uri.parse('http://a/b'));
    }
    failed = true;
    throw StateError('once');
  }, settings: _settings);

  property(
    'is skipped',
    (Draw draw) => throw StateError('A skipped property ran'),
    skip: 'skipped as the suite asks',
  );

  property(
    'runs on the browser alone',
    (Draw draw) => throw StateError('A browser property ran'),
    testOn: 'browser',
  );

  property(
    'is tagged out',
    (Draw draw) => throw StateError('A tagged-out property ran'),
    tags: 'tagged-out',
  );

  property(
    'is skipped on the VM',
    (Draw draw) => throw StateError('A property skipped on the VM ran'),
    onPlatform: {'vm': Skip('skipped on the VM as the suite asks')},
  );

  group('retried', () {
    int attempts = 0;
    tearDown(() => attempts++);

    property('passes on its retry', (Draw draw) {
      if (attempts == 0) throw StateError('the first attempt');
    }, retry: 1);
  });

  property('fails on each retry', (Draw draw) {
    throw StateError('every attempt');
  }, retry: 1);

  test('fails inside a test that stands', () async {
    await forAll((Draw draw) {
      expect(draw(.boolean(), label: 'b'), isFalse);
    }, settings: _settings);
  });
}
