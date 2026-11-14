part of 'gen.dart';

/// [value]'s text, as a report of the run prints it.
///
/// A string is written as a single-quoted Dart literal of printable ASCII
/// alone, every other character escaped, so an empty string, its whitespace
/// and a character drawn like another all show. A list, a set or a map writes
/// its elements so, and stands as `[...]` or `{...}` where it holds itself, as
/// its own `toString` does. Any other value's text is its `toString`.
String _textOf(Object? value) => _written(value, .identity());

/// [value]'s text, with each collection in [open] written as `[...]` or
/// `{...}`, since [value] lies inside it.
String _written(Object? value, Set<Object> open) => switch (value) {
  String() => _literal(value),
  List() => _enclosed(
    value,
    '[',
    ']',
    open,
    value.map((Object? element) => _written(element, open)),
  ),
  Set() => _enclosed(
    value,
    '{',
    '}',
    open,
    value.map((Object? element) => _written(element, open)),
  ),
  Map() => _enclosed(
    value,
    '{',
    '}',
    open,
    value.entries.map(
      (MapEntry<Object?, Object?> entry) =>
          '${_written(entry.key, open)}: ${_written(entry.value, open)}',
    ),
  ),
  _ => '$value',
};

/// [collection]'s text, its [parts] between [opens] and [closes], or `...`
/// between them where [collection] is already open.
///
/// [parts] is lazy, so each part is written after [collection] is opened.
String _enclosed(
  Object collection,
  String opens,
  String closes,
  Set<Object> open,
  Iterable<String> parts,
) {
  if (!open.add(collection)) return '$opens...$closes';
  final String text = '$opens${parts.join(', ')}$closes';
  open.remove(collection);
  return text;
}

/// [text] as a single-quoted Dart literal of printable ASCII alone.
String _literal(String text) {
  final StringBuffer literal = .new("'");
  for (final int rune in text.runes) {
    literal.write(switch (rune) {
      0x08 => r'\b',
      0x09 => r'\t',
      0x0A => r'\n',
      0x0B => r'\v',
      0x0C => r'\f',
      0x0D => r'\r',
      0x24 => r'\$',
      0x27 => r"\'",
      0x5C => r'\\',
      >= 0x20 && <= 0x7E => String.fromCharCode(rune),
      _ => '\\u{${rune.toRadixString(16)}}',
    });
  }
  literal.write("'");
  return '$literal';
}
