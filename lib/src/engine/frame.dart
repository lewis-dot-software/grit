/// One frame of a stack: the library it runs in, and the line.
final class Frame {
  /// The frame at [line] of [uri].
  Frame(this.uri, this.line);

  /// The frames of [stackTrace], innermost first, in the Dart VM's form.
  ///
  /// A line that names no library and line, such as an asynchronous
  /// suspension, is no frame.
  static List<Frame> of(StackTrace stackTrace) => [
    for (final RegExpMatch match in _line.allMatches(stackTrace.toString()))
      if (Uri.tryParse(match[1]!) case final Uri uri)
        .new(uri, int.parse(match[2]!)),
  ];

  /// A frame's line in the VM's form, such as
  /// `#0      main (file:///a/b.dart:12:5)`, its column optional.
  static final RegExp _line = .new(
    r'^#\d+\s+.*\((.+?):(\d+)(?::\d+)?\)$',
    multiLine: true,
  );

  /// The library the frame runs in.
  final Uri uri;

  /// The line of [uri] the frame is at.
  final int line;

  /// The package [uri] lies in: `package:<name>` for a package's library, and
  /// the scheme alone otherwise, so the files of one package's own tests and
  /// tools are one package, and the Dart SDK is `dart`.
  String get package => uri.scheme == 'package' && uri.pathSegments.isNotEmpty
      ? 'package:${uri.pathSegments.first}'
      : uri.scheme;

  @override
  bool operator ==(Object other) =>
      other is Frame && other.uri == uri && other.line == line;

  @override
  int get hashCode => Object.hash(uri, line);

  @override
  String toString() => '$uri:$line';
}
