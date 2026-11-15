part of 'gen.dart';

/// A line noted, and the line noted before it, where one was.
final class _Note {
  _Note(this.line, this.before);

  /// The line.
  final String line;

  /// The line noted before it, where one was.
  final _Note? before;
}
