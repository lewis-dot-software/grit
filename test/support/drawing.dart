import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/status.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

/// What drawing a generator from a fixed sequence came to, with the choices
/// it read.
sealed class Drawing<T> {
  Drawing._(this.record);

  /// The choices the draw read, in order.
  final ChoiceSequence record;
}

/// A draw that returned [value].
final class Drew<T> extends Drawing<T> {
  /// The draw that returned [value], having read [record].
  Drew(this.value, ChoiceSequence record) : super._(record);

  /// The value drawn.
  final T value;

  @override
  String toString() => 'drew $value from $record';
}

/// A draw the source stopped, overrun or rejected, before it returned.
final class Stopped<T> extends Drawing<T> {
  /// The draw the source stopped with [status], having read [record].
  Stopped(this.status, ChoiceSequence record) : super._(record);

  /// How the draw ended.
  final Status status;

  @override
  String toString() => 'stopped ${status.name} at $record';
}

/// Draws [gen] from [sequence]'s choices, throwing on whatever [gen] throws
/// that is not the source's stop, so no reading of the drawing passes a
/// generator that throws.
///
/// A draw the source stopped is [Stopped] whether [gen] threw or returned
/// after the stop.
Drawing<T> drawFrom<T>(Gen<T> gen, ChoiceSequence sequence) {
  final ChoiceSource source = .fixed(sequence);
  final T value;
  try {
    value = RunDraw(source)(gen);
  } on Object {
    switch (source.status(threw: true)) {
      case final Status stopped && (.overrun || .rejected):
        return Stopped(stopped, source.record);
      case .failed:
        rethrow;
      case .returned:
        throw StateError('A draw that threw ended as returned');
    }
  }
  return switch (source.status(threw: false)) {
    .returned => Drew(value, source.record),
    final Status stopped && (.overrun || .rejected) => Stopped(
      stopped,
      source.record,
    ),
    .failed => throw StateError('A draw that returned ended as failed'),
  };
}

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
