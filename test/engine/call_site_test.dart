import 'package:grit/grit.dart';
import 'package:grit/src/engine/call_site.dart';
import 'package:grit/src/store/store_key.dart';
import 'package:test/test.dart';

/// A stack in the Dart VM's form, its frames at [frames] in turn, innermost
/// first.
StackTrace _stack(List<String> frames) => .fromString(
  [for (int i = 0; i < frames.length; i++) '#$i      member (${frames[i]})']
      .join('\n'),
);

/// The frame of `member` at [line] of [uri].
Frame _at(String uri, int line) => .new('member', .parse(uri), line);

/// Matches the failure of an error of [type] thrown from [frame].
Matcher _failure(Type type, Frame? frame) => isA<Failure>()
    .having((Failure failure) => failure.type, 'type', type)
    .having((Failure failure) => failure.frame, 'frame', frame);

/// A frame of one of two members of one of two libraries, at one of two
/// lines or at none.
final Gen<Frame> _anyFrame = .build(
  (Draw draw) => .new(
    draw(.element(['snap', 'body'])),
    draw(
      .element([.parse('package:app/a.dart'), .parse('package:app/b.dart')]),
    ),
    draw(.element([null, 1, 2])),
  ),
);

/// A failure of one of two types, thrown through up to three frames.
final Gen<Failure> _anyFailure = .build(
  (Draw draw) => .new(
    draw(.element([StateError, ArgumentError])),
    draw(.list(_anyFrame, maxLength: 3)),
  ),
);

/// The call site of a search called from the consumer's library `app`,
/// through grit and the test packages.
final CallSite _fromApp = .of(
  _stack([
    'package:grit/src/engine/search.dart:40:5',
    'package:app/src/property.dart:7:3',
    'package:test_api/src/backend/declarer.dart:253:25',
    'dart:async/zone.dart:1399:13',
  ]),
);

void main() {
  group('a frame', () {
    test('is read with its member and line, past its column', () {
      expect(
        Frame.of(
          .fromString(
            '#0      main.<anonymous closure> (file:///p/test/a_test.dart:12:5)',
          ),
        ),
        <Frame>[
          .new(
            'main.<anonymous closure>',
            .parse('file:///p/test/a_test.dart'),
            12,
          ),
        ],
      );
    });

    test('is read at no line where the VM printed none', () {
      expect(
        Frame.of(.fromString('#0      snap (file:///p/test/snap_test.dart)')),
        <Frame>[.new('snap', .parse('file:///p/test/snap_test.dart'), null)],
      );
    });
  });

  group('a failure\'s frame', () {
    test('is its first in the call site\'s package, past frames of other '
        'packages before it', () {
      expect(
        _fromApp.failureOf(
          StateError('x'),
          _stack([
            'dart:core/errors.dart:10:3',
            'package:collection/src/list.dart:12:5',
            'package:app/src/sort.dart:30:9',
            'package:app/src/property.dart:9:3',
          ]),
        ),
        _failure(StateError, _at('package:app/src/sort.dart', 30)),
      );
    });

    test('is its first outside the Dart SDK, grit and every test package, '
        'where none is in the call site\'s package', () {
      expect(
        _fromApp.failureOf(
          StateError('x'),
          _stack([
            'dart:core/errors.dart:10:3',
            'package:grit/src/gen/gen.dart:70:7',
            'package:checks/src/checks.dart:2:1',
            'package:flutter_test/src/widget_tester.dart:3:1',
            'package:matcher/src/expect.dart:4:1',
            'package:stack_trace/src/chain.dart:5:1',
            'package:test/src/expect.dart:8:1',
            'package:test_api/src/backend/invoker.dart:6:1',
            'package:test_core/src/runner.dart:7:1',
            'package:collection/src/list.dart:12:5',
            'package:other/a.dart:1:1',
          ]),
        ),
        _failure(StateError, _at('package:collection/src/list.dart', 12)),
      );
    });

    test('is none where every frame is the Dart SDK\'s, grit\'s or a test '
        'package\'s', () {
      expect(
        _fromApp.failureOf(
          StateError('x'),
          _stack([
            'dart:core/errors.dart:10:3',
            'package:test_core/src/runner.dart:2:2',
            'package:grit/src/engine/search.dart:1:1',
          ]),
        ),
        _failure(StateError, null),
      );
      expect(
        _fromApp.failureOf(StateError('x'), .empty),
        _failure(StateError, null),
      );
    });

    test('is its first in the call site\'s package where the VM printed it '
        'with no line', () {
      expect(
        _fromApp.failureOf(
          UnsupportedError('x'),
          .fromString(
            '#0      snap (package:app/src/snap.dart)\n'
            '#1      body (package:app/src/property.dart:9:3)\n',
          ),
        ),
        _failure(
          UnsupportedError,
          .new('snap', .parse('package:app/src/snap.dart'), null),
        ),
      );
    });

    test('is read past asynchronous suspensions, with or without a column', () {
      expect(
        _fromApp.failureOf(
          StateError('x'),
          .fromString(
            '#0      _rootRun (dart:async/zone.dart:1399:13)\n'
            '<asynchronous suspension>\n'
            '#1      sort (package:app/src/sort.dart:31)\n',
          ),
        ),
        _failure(
          StateError,
          .new('sort', .parse('package:app/src/sort.dart'), 31),
        ),
      );
    });

    test('takes a call site\'s own test files as one package, so a frame of '
        'any of them comes first', () {
      final CallSite fromTest = .of(
        _stack([
          'package:grit/src/engine/search.dart:40:5',
          'file:///c/app/test/sort_test.dart:12:3',
        ]),
      );
      expect(
        fromTest.failureOf(
          RangeError('x'),
          _stack([
            'package:app/src/sort.dart:30:9',
            'file:///c/app/test/support/sorting.dart:5:3',
            'file:///c/app/test/sort_test.dart:14:3',
          ]),
        ),
        _failure(RangeError, _at('file:///c/app/test/support/sorting.dart', 5)),
      );
    });

    test('reads a call site with no frame of its own as naming no package', () {
      final CallSite nowhere = .of(
        _stack(['package:grit/src/engine/search.dart:40:5']),
      );
      expect(
        nowhere.failureOf(
          StateError('x'),
          _stack([
            'package:collection/src/list.dart:12:5',
            'package:app/src/sort.dart:30:9',
          ]),
        ),
        _failure(StateError, _at('package:collection/src/list.dart', 12)),
      );
    });

    test('is the line an error was thrown from, read from a real throw', () {
      final CallSite here = .of(.current);
      final Frame frame = .of(.current).first;
      try {
        throw const FormatException('thrown');
      } on FormatException catch (error, stackTrace) {
        expect(
          here.failureOf(error, stackTrace),
          _failure(
            FormatException,
            .new(frame.member, frame.uri, frame.line! + 2),
          ),
        );
      }
    });
  });

  group('a call site\'s key', () {
    test('is every frame of its stack in its package, by library and line '
        'where each carries one, innermost first', () {
      final CallSite site = .of(
        _stack([
          'package:grit/src/api/property.dart:30:5',
          'file:///p/test/support/helper.dart:7:3',
          'package:collection/src/list.dart:12:5',
          'file:///p/test/a_test.dart:20:9',
          'package:test_api/src/backend/declarer.dart:253:25',
          'file:///p/test/a_test.dart:4:1',
        ]),
      );
      expect(
        site.key.text,
        'file:///p/test/support/helper.dart:7\n'
        'file:///p/test/a_test.dart:20\n'
        'file:///p/test/a_test.dart:4',
      );
    });

    test('takes a frame the VM printed with no line by its library and '
        'member', () {
      final CallSite site = .of(
        .fromString(
          '#0      runProperty (package:grit/src/api/property.dart:30:5)\n'
          '#1      check (file:///p/test/support/helper.dart)\n'
          '#2      main.<anonymous closure> (file:///p/test/a_test.dart:20:9)',
        ),
      );
      expect(
        site.key.text,
        'file:///p/test/support/helper.dart, in check\n'
        'file:///p/test/a_test.dart:20',
      );
    });

    test('is the same for two calls from one line, whatever their columns', () {
      expect(
        CallSite.of(_stack(['file:///p/test/a_test.dart:20:9'])).key,
        CallSite.of(_stack(['file:///p/test/a_test.dart:20:31'])).key,
      );
    });

    test(
      'differs for calls from two lines, or from one behind two callers',
      () {
        final StoreKey here = CallSite.of(
          _stack(['file:///p/test/a_test.dart:20:9']),
        ).key;
        expect(
          CallSite.of(_stack(['file:///p/test/a_test.dart:21:9'])).key,
          isNot(here),
        );
        expect(
          CallSite.of(
            _stack([
              'file:///p/test/a_test.dart:20:9',
              'file:///p/test/a_test.dart:30:1',
            ]),
          ).key,
          isNot(here),
        );
      },
    );

    test('differs for a frame with no line once its member moves to another '
        'file', () {
      expect(
        CallSite.of(_stack(['file:///p/test/support/b.dart'])).key,
        isNot(CallSite.of(_stack(['file:///p/test/support/a.dart'])).key),
      );
    });

    test('holds no frame where its stack has none of its own', () {
      expect(
        CallSite.of(
          _stack([
            'package:grit/src/api/property.dart:30:5',
            'dart:async/zone.dart:1:1',
          ]),
        ).key.text,
        '',
      );
    });
  });

  group('two failures', () {
    final StackTrace at = _stack(['package:app/src/sort.dart:30:9']);
    final StackTrace elsewhere = _stack(['package:app/src/sort.dart:31:9']);

    /// Whether the failures of [first] and [second], each thrown with its
    /// stack, are alike, read from the first.
    bool alike((Object, StackTrace) first, (Object, StackTrace) second) =>
        _fromApp
            .failureOf(first.$1, first.$2)
            .isAlike(_fromApp.failureOf(second.$1, second.$2));

    test('are the same where each error has one type and one frame', () {
      expect(alike((StateError('a'), at), (StateError('b'), at)), isTrue);
    });

    test('differ where their errors\' types differ', () {
      expect(alike((StateError('a'), at), (ArgumentError('a'), at)), isFalse);
    });

    test('differ where their frames differ', () {
      expect(
        alike((StateError('a'), at), (StateError('a'), elsewhere)),
        isFalse,
      );
    });

    test('are the same where their frames are at one line of one library, '
        'whatever their members', () {
      expect(
        alike(
          (
            StateError('a'),
            .fromString('#0      f (package:app/src/a.dart:4:3)'),
          ),
          (
            StateError('a'),
            .fromString(
              '#0      f.<anonymous closure> (package:app/src/a.dart:4:9)',
            ),
          ),
        ),
        isTrue,
      );
    });

    test('are the same where one\'s frame has no line, in a member the '
        'other\'s frames run through, read from either', () {
      // One throw from `snap` as the VM runs it unoptimised, then optimised,
      // then inlined into `body`.
      final List<StackTrace> stacks = [
        .fromString(
          '#0      double.toInt (dart:core-patch/double.dart)\n'
          '#1      double.round (dart:core-patch/double.dart:196:34)\n'
          '#2      snap (package:app/src/snap.dart:3:12)\n'
          '#3      body (package:app/src/property.dart:9:3)\n',
        ),
        .fromString(
          '#0      snap (package:app/src/snap.dart)\n'
          '#1      body (package:app/src/property.dart:9:3)\n',
        ),
        .fromString(
          '#0      body (package:app/src/property.dart)\n'
          '#1      Search._ran (package:grit/src/engine/search.dart:320:15)\n',
        ),
      ];
      for (final StackTrace first in stacks) {
        for (final StackTrace second in stacks) {
          expect(
            alike(
              (UnsupportedError('x'), first),
              (UnsupportedError('x'), second),
            ),
            isTrue,
          );
        }
      }
    });

    test('differ where one\'s frame has no line, in a member the other\'s '
        'frames never run through, read from either', () {
      final StackTrace inlined = .fromString(
        '#0      body (package:app/src/property.dart)\n',
      );
      final StackTrace other = .fromString(
        '#0      snap (package:app/src/snap.dart:3:12)\n'
        '#1      other (package:app/src/property.dart:9:3)\n',
      );
      expect(
        alike((StateError('x'), inlined), (StateError('x'), other)),
        isFalse,
      );
      expect(
        alike((StateError('x'), other), (StateError('x'), inlined)),
        isFalse,
      );
    });

    test('are the same where each error has one type and no frame grit '
        'reads, whatever threw them', () {
      expect(
        alike((StateError('a'), .empty), (StateError('b'), .empty)),
        isTrue,
      );
    });

    test('differ where one error has no frame grit reads and the other has '
        'one, read from either', () {
      expect(alike((StateError('a'), .empty), (StateError('a'), at)), isFalse);
      expect(alike((StateError('a'), at), (StateError('a'), .empty)), isFalse);
    });

    property('Two failures are alike read from either, or from neither.', (
      Draw draw,
    ) {
      final Failure first = draw(_anyFailure, label: 'first');
      final Failure second = draw(_anyFailure, label: 'second');
      expect(first.isAlike(second), second.isAlike(first));
    });

    property('A failure is alike itself.', (Draw draw) {
      final Failure failure = draw(_anyFailure, label: 'failure');
      expect(failure.isAlike(failure), isTrue);
    });
  });
}
