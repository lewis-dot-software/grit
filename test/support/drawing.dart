import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/choice/status.dart';

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
