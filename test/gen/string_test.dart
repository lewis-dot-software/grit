import 'package:grit/grit.dart';
import 'package:grit/src/choice/status.dart';
import 'package:test/test.dart';

import '../support/alphabets.dart';
import '../support/bits.dart';
import '../support/bounds.dart';
import '../support/draw_from.dart';
import '../support/drawing.dart';
import '../support/integer_range.dart';
import '../support/long_end.dart';
import '../support/small.dart';

/// Small alphabets whose every index a choice up to 2 reaches, one holding a
/// character past the Basic Multilingual Plane, two code units long.
final List<String> _small = ['a', 'ab', 'a😀c'];

/// Each minimum and maximum length checked, a null maximum for none.
final List<Bounds> _lengths = [
  (min: 0, max: null),
  (min: 1, max: null),
  (min: 2, max: null),
  (min: 0, max: 0),
  (min: 0, max: 2),
  (min: 1, max: 3),
  (min: 2, max: 2),
];

/// The code point at [index] of [alphabet], drawn as a string of one.
int _at(Alphabet alphabet, int index) => (drawFrom(
  .string(alphabet: alphabet, minLength: 1, maxLength: 1),
  sequenceOf([0, index, 0]),
) as Drew<String>).value.runes.single;

/// Every string of exactly [length] of [codePoints].
Iterable<String> _strings(List<int> codePoints, int length) sync* {
  if (length == 0) {
    yield '';
    return;
  }
  for (final String rest in _strings(codePoints, length - 1)) {
    for (final int codePoint in codePoints) {
      yield '$rest${String.fromCharCode(codePoint)}';
    }
  }
}

/// Pairs of a "one more" choice and an index into an alphabet of [size]
/// characters, flattened, so a record reaches past a string's maximum as
/// often as not.
Gen<List<int>> _choices(int size) => .list(
  .build((Draw draw) => [draw(bit), draw(.integer(min: 0, max: size - 1))]),
).map((List<List<int>> pairs) => [for (final List<int> pair in pairs) ...pair]);

/// A preset alphabet, or one of a few drawn characters.
final Gen<Letters> _anyAlphabet = .oneOf([
  .element(presets),
  .string(minLength: 1, maxLength: 6).map(lettersOf),
]);

/// Checks that deleting each code point's span from the record [drew] read
/// draws from [gen] the same string with that code point removed.
///
/// A code point's span is its "one more" choice and the choice of its index.
void _expectEachDeletion(Gen<String> gen, Drew<String> drew, {String? reason}) {
  final List<Choice> choices = drew.record.choices;
  final List<int> codePoints = drew.value.runes.toList();
  for (int i = 0; i < codePoints.length; i++) {
    final ChoiceSequence shorter = .new([
      ...choices.take(2 * i),
      ...choices.skip(2 * i + 2),
    ]);
    final String deleting = '$reason: ${drew.record} less code point $i';
    final Drawing<String> drawing = drawFrom(gen, shorter);
    expect(drawing, isA<Drew<String>>(), reason: deleting);
    expect(
      (drawing as Drew<String>).value,
      String.fromCharCodes([...codePoints]..removeAt(i)),
      reason: deleting,
    );
    expect(drawing.record, shorter, reason: deleting);
  }
}

void main() {
  test('Every string drawn has from its minimum to its maximum code points, '
      'and holds only its alphabet\'s.', () {
    for (final Letters letters in _small.map(lettersOf)) {
      for (final (min: int minLength, max: int? maxLength) in _lengths) {
        final Gen<String> gen = .string(
          alphabet: letters.alphabet,
          minLength: minLength,
          maxLength: maxLength,
        );
        final String name = '${letters.name}, $minLength to $maxLength long';
        int drawn = 0;
        for (final ChoiceSequence sequence in everySequence(
          length: 7,
          bound: 2,
        )) {
          if (drawFrom(gen, sequence) case Drew(:final String value)) {
            final String reason = '$name: $sequence';
            expect(
              value.runes.length,
              inInclusiveRange(minLength, maxLength ?? 7),
              reason: reason,
            );
            expect(value.runes.every(letters.holds), isTrue, reason: reason);
            drawn++;
          }
        }
        expect(drawn, greaterThan(0), reason: name);
      }
    }
  });

  test('Every string its length bounds and alphabet allow is drawn by some '
      'sequence.', () {
    // A string of three code points reads seven choices, so every string of
    // up to three is checked for.
    for (final String characters in _small) {
      final List<int> codePoints = characters.runes.toList();
      for (final (min: int minLength, max: int? maxLength) in _lengths) {
        final Gen<String> gen = .string(
          alphabet: .of(characters),
          minLength: minLength,
          maxLength: maxLength,
        );
        final Set<String> drawn = {
          for (final ChoiceSequence sequence in everySequence(
            length: 7,
            bound: 2,
          ))
            if (drawFrom(gen, sequence) case Drew(:final String value)) value,
        };
        final int longest = maxLength == null || maxLength > 3 ? 3 : maxLength;
        for (int length = minLength; length <= longest; length++) {
          expect(
            drawn,
            containsAll(_strings(codePoints, length)),
            reason: '"$characters", $minLength to $maxLength long',
          );
        }
      }
    }
  });

  test('Deleting one code point\'s span from the record of a string longer '
      'than its minimum draws the string without that code point.', () {
    for (final String characters in _small) {
      for (final (min: int minLength, max: int? maxLength) in _lengths) {
        final Gen<String> gen = .string(
          alphabet: .of(characters),
          minLength: minLength,
          maxLength: maxLength,
        );
        final String name = '"$characters", $minLength to $maxLength long';
        int deleted = 0;
        for (final ChoiceSequence sequence in everySequence(
          length: 8,
          bound: 2,
        )) {
          if (drawFrom(gen, sequence) case final Drew<String> drew
              when drew.value.runes.length > minLength) {
            _expectEachDeletion(gen, drew, reason: name);
            deleted += drew.value.runes.length;
          }
        }
        // A string held at one length has no shorter string to draw.
        if (minLength != maxLength) {
          expect(deleted, greaterThan(20), reason: name);
        }
      }
    }
  });

  test('draws each of a preset\'s characters at one index, and nothing '
      'else', () {
    for (final Letters preset in presets) {
      final List<int> codePoints = [
        for (int index = 0; index < preset.size; index++)
          _at(preset.alphabet, index),
      ];
      expect(codePoints.every(preset.holds), isTrue, reason: preset.name);
      expect(codePoints.toSet(), hasLength(preset.size), reason: preset.name);
      expect(
        (drawFrom(
          .string(alphabet: preset.alphabet, minLength: 1),
          sequenceOf([0, preset.size]),
        ) as Stopped<String>).status,
        Status.rejected,
        reason: preset.name,
      );
    }
  });

  test('orders each preset\'s characters as its docs give, simplest '
      'first', () {
    String all(Alphabet alphabet, int size) => .fromCharCodes([
      for (int index = 0; index < size; index++) _at(alphabet, index),
    ]);
    const String lower = 'abcdefghijklmnopqrstuvwxyz';
    const String upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String digits = '0123456789';
    expect(all(.lowerCase, 26), lower);
    expect(all(.upperCase, 26), upper);
    expect(all(.letters, 52), '$upper$lower');
    expect(all(.digits, 10), digits);
    expect(all(.lettersAndDigits, 62), '$digits$upper$lower');

    // `0` to `Z`, then from `/` down to the first ASCII character, then from
    // `[` up to the last.
    final List<int> ascii = [
      for (int c = 0x30; c <= 0x5A; c++) c,
      for (int c = 0x2F; c >= 0; c--) c,
      for (int c = 0x5B; c <= 0x7F; c++) c,
    ];
    expect(all(.ascii, 128).runes, ascii);
    expect(all(.unicode, 128).runes, ascii);
    // Past the ASCII, each index stands for its own code point until the
    // surrogates, and 0x800 past it after them.
    for (final (:int index, :int codePoint) in [
      (index: 0x80, codePoint: 0x80),
      (index: 0xD7FF, codePoint: 0xD7FF),
      (index: 0xD800, codePoint: 0xE000),
      (index: 0x10F7FF, codePoint: 0x10FFFF),
    ]) {
      expect(_at(.unicode, index), codePoint, reason: 'index $index');
    }
  });

  test('draws over every Unicode scalar value by default', () {
    final Gen<String> gen = .string(minLength: 1, maxLength: 1);
    expect((drawFrom(gen, sequenceOf([0, 0, 0])) as Drew<String>).value, '0');
    expect(
      (drawFrom(gen, sequenceOf([0, 0x10F7FF, 0])) as Drew<String>).value,
      '\u{10FFFF}',
    );
    expect(
      (drawFrom(gen, sequenceOf([0, 0x10F800])) as Stopped<String>).status,
      Status.rejected,
    );
  });

  test('draws one more code point at each choice of 1, and ends at a 0', () {
    final Drawing<String> drawing = drawFrom(
      .string(alphabet: .of('abc')),
      sequenceOf([1, 2, 1, 0, 0, 9]),
    );
    expect((drawing as Drew<String>).value, 'ca');
    expect(drawing.record, sequenceOf([1, 2, 1, 0, 0]));
  });

  test('reaches the last quarter of its length range in a fair share of '
      'runs, from a narrow range and a wide one', () {
    for (final IntegerRange range in sizeRanges) {
      final Gen<String> gen = .string(
        alphabet: .ascii,
        minLength: range.min,
        maxLength: range.max,
      );
      expect(
        longEndRuns(gen, range, (String string) => string.runes.length),
        greaterThan(10),
        reason: '$range',
      );
    }
  });

  test('counts a character past the Basic Multilingual Plane as one code '
      'point, never two code units', () {
    final Drawing<String> drawing = drawFrom(
      .string(alphabet: .of('😀'), minLength: 2, maxLength: 2),
      sequenceOf([0, 0, 0, 0, 0]),
    );
    final String value = (drawing as Drew<String>).value;
    expect(value, '😀😀');
    expect(value.runes, hasLength(2));
    expect(value, hasLength(4));
  });

  test('an alphabet of a string keeps each character where it first '
      'appears', () {
    final Alphabet alphabet = .of('abcab');
    expect([for (int i = 0; i < 3; i++) _at(alphabet, i)], 'abc'.runes);
    expect(
      (drawFrom(
        .string(alphabet: alphabet, minLength: 1),
        sequenceOf([0, 3]),
      ) as Stopped<String>).status,
      Status.rejected,
    );
  });

  group('a consumer\'s mistake', () {
    test('an alphabet of no characters is thrown', () {
      expect(() => Alphabet.of(''), throwsArgumentError);
    });

    test('an alphabet holding a lone surrogate is thrown', () {
      expect(() => Alphabet.of('a\uD800'), throwsArgumentError);
      expect(() => Alphabet.of('\uDC00b'), throwsArgumentError);
    });

    test('a negative minimum length is thrown', () {
      expect(() => Gen.string(minLength: -1), throwsRangeError);
    });

    test('a minimum length above the maximum is thrown', () {
      expect(() => Gen.string(minLength: 2, maxLength: 1), throwsArgumentError);
    });
  });

  group('on grit, over larger inputs', () {
    property('Every string drawn has from its minimum to its maximum code '
        'points, and holds only its alphabet\'s.', (Draw draw) {
      final Letters letters = draw(_anyAlphabet, label: 'alphabet');
      final (min: int minLength, max: int? maxLength) = draw(
        bounds,
        label: 'lengths',
      );
      final List<int> choices = draw(_choices(letters.size), label: 'choices');
      final Drawing<String> drawing = drawFrom(
        .string(
          alphabet: letters.alphabet,
          minLength: minLength,
          maxLength: maxLength,
        ),
        sequenceOf([...choices, ...zeros]),
      );
      if (drawing case Drew(:final String value)) {
        expect(
          value.runes.length,
          inInclusiveRange(minLength, maxLength ?? Choice.largest.value),
        );
        expect(value.runes.every(letters.holds), isTrue);
      }
    });

    property('Every string its length bounds and alphabet allow is drawn by '
        'some sequence.', (Draw draw) {
      final String characters = draw(
        .string(minLength: 1, maxLength: 6),
        label: 'characters',
      );
      final List<int> codePoints = characters.runes.toSet().toList();
      final (min: int minLength, max: int? maxLength) = draw(
        bounds,
        label: 'lengths',
      );
      final int length = draw(
        .integer(min: minLength, max: maxLength ?? minLength + 8),
        label: 'length',
      );
      final List<int> indices = draw(
        .list(
          .integer(min: 0, max: codePoints.length - 1),
          minLength: length,
          maxLength: length,
        ),
        label: 'indices',
      );
      final Drawing<String> drawing = drawFrom(
        .string(
          alphabet: .of(characters),
          minLength: minLength,
          maxLength: maxLength,
        ),
        sequenceOf([
          for (final int index in indices) ...[1, index],
          0,
        ]),
      );
      expect(
        (drawing as Drew<String>).value,
        String.fromCharCodes([for (final int i in indices) codePoints[i]]),
      );
    });

    property('Deleting one code point\'s span from the record of a string '
        'longer than its minimum draws the string without that code point.', (
      Draw draw,
    ) {
      final Letters letters = draw(_anyAlphabet, label: 'alphabet');
      final (min: int minLength, max: int? maxLength) = draw(
        bounds,
        label: 'lengths',
      );
      final Gen<String> gen = .string(
        alphabet: letters.alphabet,
        minLength: minLength,
        maxLength: maxLength,
      );
      final List<int> choices = draw(_choices(letters.size), label: 'choices');
      final Drawing<String> drawing = drawFrom(
        gen,
        sequenceOf([...choices, ...zeros]),
      );
      // A string at its minimum length has no shorter string to draw.
      draw.assume(
        drawing is Drew<String> && drawing.value.runes.length > minLength,
      );
      _expectEachDeletion(gen, drawing as Drew<String>);
    });
  });
}
