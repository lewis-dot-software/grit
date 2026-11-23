import 'package:grit/grit.dart';
import 'package:grit/src/choice/decoding.dart';
import 'package:grit/src/choice/token.dart';
import 'package:test/test.dart';

import '../support/inputs.dart';
import '../support/small.dart';

/// The choices either side of where a choice takes a second and a third base
/// 36 digit, and the largest a choice holds, so the small sequences reach
/// tokens of several digits a choice.
final List<int> _wide = [35, 36, 1295, 1296, Choice.largest.value];

/// Every sequence of up to three choices from 0 to 36, then each of up to
/// two choices from [_wide], so a choice of one digit and of several meet.
Iterable<ChoiceSequence> get _smallSequences sync* {
  yield* everySequence(length: 3, bound: 36);
  for (final int a in _wide) {
    yield sequenceOf([a]);
    for (final int b in _wide) {
      yield sequenceOf([a, b]);
      yield sequenceOf([0, a, b]);
    }
  }
}

/// The characters a token may hold: none ends a Dart string literal, starts
/// an interpolation or an escape, or ends a line.
final RegExp _safe = .new(r'^[0-9a-z.:]*$');

/// The sequence [text] decodes to, or null where it decodes to none.
ChoiceSequence? _decoded(String text) => switch (Token.decode(text)) {
  Decoded(:final ChoiceSequence sequence) => sequence,
  NotAToken() || OtherFormat() => null,
};

/// Texts that are no token: a token's shape broken at each of its parts.
const List<String> _noTokens = [
  '',
  'grit1',
  'grit:0',
  'grit1x:0',
  'Grit1:0',
  ' grit1:0',
  'grit1:0 ',
  'grit1:0\n',
  'grit1:.',
  'grit1:0.',
  'grit1:.0',
  'grit1:0..1',
  'grit1:00',
  'grit1:01',
  'grit1:A',
  'grit1:-1',
  'grit1:+1',
  'grit1:0,1',
  'grit1:1y2p0ij32e8e8',
  'grit1:zzzzzzzzzzzzzz',
  '[1, 3]',
];

/// Texts that open with another format's version.
const List<String> _otherFormats = [
  'grit0:0',
  'grit2:0',
  'grit2:',
  'grit2:anything at all',
  'grit10:0',
  'grit01:0',
];

/// How a text decodes, by its kind alone.
enum _Kind { token, otherFormat, noToken }

/// The kind of [text], told with no appeal to the codec: a token where it is
/// its format and colon, then choices joined by dots, each a 0 or base 36
/// digits with no leading zero, no larger than the largest choice.
_Kind _kindOf(String text) {
  final String? format = RegExp(r'^(grit\d+):').firstMatch(text)?[1];
  if (format != null && format != 'grit1') return .otherFormat;
  final RegExpMatch? match = RegExp(
    r'^grit1:((0|[1-9a-z][0-9a-z]*)(\.(0|[1-9a-z][0-9a-z]*))*)?$',
  ).firstMatch(text);
  if (match == null) return .noToken;
  final BigInt largest = .from(Choice.largest.value);
  final bool fits = (match[1]?.split('.') ?? const <String>[]).every(
    (String digits) => BigInt.parse(digits, radix: 36) <= largest,
  );
  return fits ? .token : .noToken;
}

/// The kind of [decoding].
_Kind _kindOfDecoding(Decoding decoding) => switch (decoding) {
  Decoded() => .token,
  OtherFormat() => .otherFormat,
  NotAToken() => .noToken,
};

/// Every text of up to [length] characters of a token's alphabet and a few
/// that are none, after each of a few openings, among them each leading zero,
/// stray dot and choice past the largest.
Iterable<String> _everyText({required int length}) sync* {
  const List<String> openings = ['', 'grit1', 'grit1:', 'grit2:', 'grit:'];
  const List<String> alphabet = ['0', '1', 'z', '.', ':', 'A'];
  Iterable<String> texts(int length) sync* {
    if (length == 0) {
      yield '';
      return;
    }
    for (final String rest in texts(length - 1)) {
      for (final String char in alphabet) {
        yield '$rest$char';
      }
    }
  }

  for (final String opening in openings) {
    for (int size = 0; size <= length; size++) {
      for (final String rest in texts(size)) {
        yield '$opening$rest';
      }
    }
  }
  // Choices at and past the largest, which no shorter text reaches.
  yield 'grit1:1y2p0ij32e8e7';
  yield 'grit1:1y2p0ij32e8e8';
  yield 'grit1:0.zzzzzzzzzzzzzz';
}

/// Text of one of a few openings, then any number of characters drawn one by
/// one, each one a token may hold or one of a few it may not.
final Gen<String> _anyText = .build((Draw draw) {
  final String opening = draw(
    .element(['', 'grit1:', 'grit2:', 'grit:', 'grit1']),
  );
  final List<String> rest = draw(
    .list(.element([...'0123456789abcxyz.:'.split(''), 'A', ' ', '-'])),
  );
  return '$opening${rest.join()}';
});

void main() {
  group('a token', () {
    test('opens with its format\'s version, then each choice in base 36, '
        'joined by dots', () {
      expect(
        Token.encode(sequenceOf([0, 3, 35, 36, 1296])),
        'grit1:0.3.z.10.100',
      );
    });

    test('of the empty sequence is its format and colon alone', () {
      expect(Token.encode(sequenceOf([])), 'grit1:');
      expect(_decoded('grit1:'), sequenceOf([]));
    });

    test('of the largest choice decodes to it', () {
      final ChoiceSequence largest = .new([.largest]);
      expect(_decoded(Token.encode(largest)), largest);
    });

    test('broken at any of its parts is no token', () {
      for (final String text in _noTokens) {
        expect(Token.decode(text), isA<NotAToken>(), reason: text);
      }
    });

    test('of another format says its format', () {
      for (final String text in _otherFormats) {
        expect(
          Token.decode(text),
          isA<OtherFormat>().having(
            (OtherFormat other) => other.format,
            'format',
            text.substring(0, text.indexOf(':')),
          ),
          reason: text,
        );
      }
    });
  });

  group('over every small sequence', () {
    test('REP-8: The token of any sequence: is one line of ASCII, safe '
        "inside a Dart string literal, and opens with its format's "
        'version.', () {
      for (final ChoiceSequence sequence in _smallSequences) {
        final String token = Token.encode(sequence);
        expect(token, matches(_safe), reason: '$sequence');
        expect(token, startsWith('${Token.format}:'), reason: '$sequence');
      }
    });

    test('REP-6: Decoding the token of any sequence gives that sequence '
        'back.', () {
      for (final ChoiceSequence sequence in _smallSequences) {
        expect(_decoded(Token.encode(sequence)), sequence, reason: '$sequence');
      }
    });

    test('REP-7: Text that decodes is the one token its sequence '
        'encodes to, so no two tokens name one sequence.', () {
      int decoded = 0;
      for (final String text in _everyText(length: 4)) {
        if (_decoded(text) case final ChoiceSequence sequence) {
          decoded++;
          expect(Token.encode(sequence), text, reason: text);
        }
      }
      // A text such as grit1:0.1 decodes, so a check of none fails.
      expect(decoded, greaterThan(0));
    });

    test('REP-9: Text that is no token, or a token of another format, '
        'never decodes to a sequence, and its error says which.', () {
      final Set<_Kind> seen = {};
      for (final String text in _everyText(length: 4)) {
        final _Kind kind = _kindOf(text);
        seen.add(kind);
        expect(_kindOfDecoding(Token.decode(text)), kind, reason: text);
      }
      expect(seen, _Kind.values.toSet());
    });
  });

  group('on grit, over larger inputs', () {
    property('REP-8: The token of any sequence: is one line of ASCII, '
        'safe inside a Dart string literal, and opens with its '
        "format's version.", (Draw draw) {
      final String token = Token.encode(draw(anySequence, label: 'sequence'));
      expect(token, matches(_safe));
      expect(token, startsWith('${Token.format}:'));
    });

    property('REP-6: Decoding the token of any sequence gives that '
        'sequence back.', (Draw draw) {
      final ChoiceSequence sequence = draw(anySequence, label: 'sequence');
      expect(_decoded(Token.encode(sequence)), sequence);
    });

    property('REP-7: Text that decodes is the one token its sequence '
        'encodes to, so no two tokens name one sequence.', (Draw draw) {
      final String text = draw(_anyText, label: 'text');
      if (_decoded(text) case final ChoiceSequence sequence) {
        expect(Token.encode(sequence), text);
      }
    });

    property('REP-9: Text that is no token, or a token of another '
        'format, never decodes to a sequence, and its error says '
        'which.', (Draw draw) {
      final String text = draw(_anyText, label: 'text');
      expect(_kindOfDecoding(Token.decode(text)), _kindOf(text));
    });
  });
}
