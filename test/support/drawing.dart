import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/status.dart';
import 'package:grit/src/gen/gen.dart';

import 'small.dart';

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

/// A draw that ended with [status] before it returned.
final class Stopped<T> extends Drawing<T> {
  /// The draw that ended with [status], having read [record].
  Stopped(this.status, ChoiceSequence record) : super._(record);

  /// How the draw ended.
  final Status status;

  @override
  String toString() => 'stopped ${status.name} at $record';
}

/// Draws [gen] from [sequence]'s choices.
Drawing<T> drawFrom<T>(Gen<T> gen, ChoiceSequence sequence) {
  final ChoiceSource source = .fixed(sequence);
  late final T value;
  final Status status = run(source, () => value = Draw(source)(gen));
  return switch (status) {
    .returned => Drew(value, source.record),
    .overrun || .rejected || .failed => Stopped(status, source.record),
  };
}
