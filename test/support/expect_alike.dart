import 'package:grit/src/choice/status.dart';
import 'package:test/test.dart';

import 'drawing.dart';

/// Fails the test where [actual] did not come to what [expected] did: the
/// same value drawn, or the same stop, having read the same record.
void expectAlike<T>(Drawing<T> actual, Drawing<T> expected, {String? reason}) {
  expect(actual.record, expected.record, reason: reason);
  switch ((actual, expected)) {
    case (Drew(value: final T a), Drew(value: final T b)):
      expect(a, b, reason: reason);
    case (Stopped(status: final Status a), Stopped(status: final Status b)):
      expect(a, b, reason: reason);
    case (Drew(), Stopped()) || (Stopped(), Drew()):
      fail('${reason ?? 'The draw'}: $actual, where $expected was due');
  }
}
