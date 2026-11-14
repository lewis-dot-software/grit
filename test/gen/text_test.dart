import 'package:grit/grit.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

import '../support/small.dart';

/// The text a draw keeps of [value], drawn by a body that makes no choice.
String _textOf(Object? value) {
  final RunDraw draw = .new(.fixed(sequenceOf([])));
  draw(Gen.build((Draw _) => value));
  return draw.draws.single.text;
}

/// The string [literal] stands for, read as a single-quoted Dart literal.
String _read(String literal) {
  expect(literal, allOf(startsWith("'"), endsWith("'")));
  final StringBuffer read = .new();
  final RegExp token = RegExp(r'\\u\{([0-9a-f]+)\}|\\(.)|(.)', dotAll: true);
  for (final RegExpMatch match in token.allMatches(
    literal.substring(1, literal.length - 1),
  )) {
    final String? codePoint = match[1];
    final String? escaped = match[2];
    if (codePoint != null) {
      read.writeCharCode(int.parse(codePoint, radix: 16));
    } else if (escaped != null) {
      read.write(switch (escaped) {
        'b' => '\b',
        't' => '\t',
        'n' => '\n',
        'v' => '\v',
        'f' => '\f',
        'r' => '\r',
        r'$' || "'" || r'\' => escaped,
        _ => fail('$literal escapes $escaped, which Dart reads otherwise'),
      });
    } else {
      final String character = match[3]!;
      if (character case "'" || r'$' || r'\') {
        fail('$literal holds $character bare, which ends or breaks a literal');
      }
      read.write(character);
    }
  }
  return '$read';
}

/// A string of any UTF-16 code units, lone surrogates among them.
final Gen<String> _units = .build(
  (Draw draw) => .fromCharCodes(draw(.list(.integer(min: 0, max: 0xFFFF)))),
);

/// A string over the characters a literal escapes by name or would read
/// otherwise, beside a space and a letter.
final Gen<String> _special = .string(alphabet: .of("a '\\\$\b\t\n\v\f\r"));

void main() {
  group('a drawn string', () {
    test('that is empty prints as a pair of quotes', () {
      expect(_textOf(''), "''");
    });

    test('prints its spaces, trailing ones among them, inside its quotes', () {
      expect(
        [_textOf('a '), _textOf('a'), _textOf('  ')],
        ["'a '", "'a'", "'  '"],
      );
    });

    test('escapes a tab, a newline and each other control character Dart '
        'names', () {
      expect(_textOf('\b\t\n\v\f\r'), r"'\b\t\n\v\f\r'");
    });

    test('escapes a quote, a backslash and a dollar', () {
      expect(_textOf(r"it's \ $1"), r"'it\'s \\ \$1'");
    });

    test('escapes each character beyond printable ASCII by its code point', () {
      expect(
        _textOf('\u{0}\u{1f}\u{7f}\u{a0}\u{e9}\u{200b}\u{1f600}\u{d800}'),
        r"'\u{0}\u{1f}\u{7f}\u{a0}\u{e9}\u{200b}\u{1f600}\u{d800}'",
      );
    });

    test('prints each string a list, a set or a map holds so', () {
      expect(
        [
          _textOf(['', 'a ']),
          _textOf({' '}),
          _textOf({
            'k ': [''],
          }),
        ],
        ["['', 'a ']", "{' '}", "{'k ': ['']}"],
      );
    });
  });

  group('a drawn collection', () {
    test('that holds itself prints as its own text does, where it '
        're-enters', () {
      final List<Object> list = [1];
      list.add(list);
      final Map<String, Object> map = {};
      map['a'] = map;
      expect([_textOf(list), _textOf(map)], ["[1, [...]]", "{'a': {...}}"]);
    });

    test('that holds one list twice prints it whole each time', () {
      final List<String> inner = [''];
      expect(_textOf([inner, inner]), "[[''], ['']]");
    });
  });

  group('a drawn value of another type', () {
    test('prints its own text, a string inside it unquoted', () {
      expect(
        [_textOf(3), _textOf(null), _textOf(('a ', 1))],
        ['3', 'null', '(a , 1)'],
      );
    });
  });

  group('on grit, over larger inputs', () {
    property('Whatever a drawn string holds, its text is a single-quoted '
        'Dart literal of printable ASCII alone, which reads back as the '
        'string.', (Draw draw) {
      final String drawn = draw(
        .oneOf([_units, .string(alphabet: .unicode), _special]),
        label: 'drawn',
      );
      final String text = _textOf(drawn);
      expect(text.codeUnits, everyElement(inInclusiveRange(0x20, 0x7E)));
      expect(_read(text), drawn);
    });
  });
}
