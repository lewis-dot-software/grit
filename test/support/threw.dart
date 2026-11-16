import 'package:grit/grit.dart';

import 'small.dart';

/// The record `[1, 3, 0]`.
final ChoiceSequence _record = sequenceOf([1, 3, 0]);

/// A run on the record `[1, 3, 0]` that threw a [StateError] of [message]
/// from line 7 of a test, having drawn [draws] and noted [notes].
Threw threw({
  List<Drawn> draws = const [],
  List<String> notes = const [],
  String message = 'too big',
}) => .new(
  _record,
  draws,
  notes,
  error: StateError(message),
  stackTrace: .empty,
  failure: (type: StateError, frame: .new(.parse('file:///a_test.dart'), 7)),
);

/// A run on the record `[1, 3, 0]` that threw an [ArgumentError] of `odd`
/// from line 9 of a test.
final Threw threwOtherwise = .new(
  _record,
  const [],
  const [],
  error: ArgumentError('odd'),
  stackTrace: .empty,
  failure: (type: ArgumentError, frame: .new(.parse('file:///a_test.dart'), 9)),
);
