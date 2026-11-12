import 'package:grit/grit.dart';

/// A generator a property of generators is checked over, named for the
/// report of a failure, since a [Gen] prints as no more than its type.
final class Generator {
  /// The generator [gen], named [name].
  Generator(this.name, this.gen);

  /// What the generator draws, in words.
  final String name;

  /// The generator itself.
  final Gen<Object?> gen;

  @override
  String toString() => name;
}
