import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/status.dart';

/// The sequence of [values], in order.
ChoiceSequence sequenceOf(List<int> values) =>
    .new([for (final int value in values) .new(value)]);

/// Every sequence of up to [length] choices, each from 0 to [bound], in
/// shortlex order.
Iterable<ChoiceSequence> everySequence({
  required int length,
  required int bound,
}) sync* {
  for (int size = 0; size <= length; size++) {
    yield* everySequenceOf(size: size, bound: bound);
  }
}

/// Every sequence of exactly [size] choices, each from 0 to [bound], in
/// shortlex order.
Iterable<ChoiceSequence> everySequenceOf({
  required int size,
  required int bound,
}) sync* {
  if (size == 0) {
    yield sequenceOf([]);
    return;
  }
  for (final ChoiceSequence rest in everySequenceOf(
    size: size - 1,
    bound: bound,
  )) {
    for (int value = 0; value <= bound; value++) {
      yield .new([...rest.choices, .new(value)]);
    }
  }
}

/// The status of a synchronous run of [body] on [source], read from the
/// source by whether the body threw.
Status run(ChoiceSource source, void Function() body) {
  try {
    body();
  } on Object {
    return source.status(threw: true);
  }
  return source.status(threw: false);
}
