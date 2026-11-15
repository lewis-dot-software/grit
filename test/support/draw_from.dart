import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/status.dart';
import 'package:grit/src/gen/gen.dart';

import 'drawing.dart';

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
