/// One frame of a stack: the library it runs in, its member and its line.
final class Frame {
  /// The frame of [member] in [uri], at [line], or at none where the VM
  /// printed none.
  Frame(this.member, this.uri, this.line);

  /// The frames of [stackTrace], innermost first, in the Dart VM's form.
  ///
  /// A line that names no member and library, such as an asynchronous
  /// suspension, is no frame.
  static List<Frame> of(StackTrace stackTrace) => [
    for (final RegExpMatch match in _line.allMatches(stackTrace.toString()))
      if (Uri.tryParse(match[2]!) case final Uri uri)
        .new(match[1]!, uri, switch (match[3]) {
          final String line => .parse(line),
          null => null,
        }),
  ];

  /// A frame's line in the VM's form, such as
  /// `#0      main (file:///a/b.dart:12:5)`, its line and column optional.
  static final RegExp _line = .new(
    r'^#\d+\s+(.+?) \((.+?)(?::(\d+))?(?::\d+)?\)$',
    multiLine: true,
  );

  /// The function or method the frame runs, as the VM names it, such as
  /// `main.<anonymous closure>`.
  final String member;

  /// The library the frame runs in.
  final Uri uri;

  /// The line of [uri] the frame is at, or null where the VM printed none,
  /// as it does for optimised code that threw where it kept no position,
  /// such as in code it inlined into [member].
  final int? line;

  /// The package [uri] lies in: `package:<name>` for a package's library, and
  /// the scheme alone otherwise, so the files of one package's own tests and
  /// tools are one package, and the Dart SDK is `dart`.
  String get package => uri.scheme == 'package' && uri.pathSegments.isNotEmpty
      ? 'package:${uri.pathSegments.first}'
      : uri.scheme;

  /// Whether [other] runs the same member of the same library, at whatever
  /// line.
  bool runsAs(Frame other) => uri == other.uri && member == other.member;

  @override
  bool operator ==(Object other) =>
      other is Frame &&
      other.member == member &&
      other.uri == uri &&
      other.line == line;

  @override
  int get hashCode => Object.hash(member, uri, line);

  @override
  String toString() => switch (line) {
    final int line => '$uri:$line',
    null => '$uri, in $member',
  };
}
