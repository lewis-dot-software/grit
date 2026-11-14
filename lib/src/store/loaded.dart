import '../choice/choice_sequence.dart';
import '../choice/decoding.dart';

/// What a store holds under one key.
sealed class Loaded {
  Loaded._();
}

/// The key holds [sequence].
final class Stored extends Loaded {
  /// The load of [sequence].
  Stored(this.sequence) : super._();

  /// The sequence the key holds.
  final ChoiceSequence sequence;
}

/// The key holds nothing.
final class Unstored extends Loaded {
  /// The load of a key that holds nothing.
  Unstored() : super._();
}

/// The key holds text that decodes to no sequence, as [reason] says.
final class Unreadable extends Loaded {
  /// The load of text that decoded as [reason].
  Unreadable(this.reason) : super._();

  /// Why the text decodes to no sequence.
  final Undecodable reason;
}
