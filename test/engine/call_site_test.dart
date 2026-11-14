import 'package:grit/src/engine/call_site.dart';
import 'package:grit/src/engine/failure.dart';
import 'package:grit/src/engine/frame.dart';
import 'package:grit/src/store/store_key.dart';
import 'package:test/test.dart';

/// A stack in the Dart VM's form, its frames at [frames] in turn, innermost
/// first.
StackTrace _stack(List<String> frames) => .fromString(
  [for (int i = 0; i < frames.length; i++) '#$i      member (${frames[i]})']
      .join('\n'),
);

/// The failure of an error of [type] thrown from [frame].
Failure _failure(Type type, Frame? frame) => (type: type, frame: frame);

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
        _failure(StateError, .new(.parse('package:app/src/sort.dart'), 30)),
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
        _failure(
          StateError,
          .new(.parse('package:collection/src/list.dart'), 12),
        ),
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
        _failure(StateError, .new(.parse('package:app/src/sort.dart'), 31)),
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
        _failure(
          RangeError,
          .new(.parse('file:///c/app/test/support/sorting.dart'), 5),
        ),
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
        _failure(
          StateError,
          .new(.parse('package:collection/src/list.dart'), 12),
        ),
      );
    });

    test('is the line an error was thrown from, read from a real throw', () {
      final CallSite here = .of(.current);
      final int line = Frame.of(.current).first.line + 2;
      try {
        throw const FormatException('thrown');
      } on FormatException catch (error, stackTrace) {
        expect(
          here.failureOf(error, stackTrace),
          _failure(FormatException, .new(Frame.of(.current).first.uri, line)),
        );
      }
    });
  });

  group('a call site\'s key', () {
    test('is every frame of its stack in its package, by library and line, '
        'innermost first', () {
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

    test('are the same where each error has one type and one frame', () {
      expect(
        _fromApp.failureOf(StateError('a'), at),
        _fromApp.failureOf(StateError('b'), at),
      );
    });

    test('differ where their errors\' types differ', () {
      expect(
        _fromApp.failureOf(StateError('a'), at),
        isNot(_fromApp.failureOf(ArgumentError('a'), at)),
      );
    });

    test('differ where their frames differ', () {
      expect(
        _fromApp.failureOf(StateError('a'), at),
        isNot(_fromApp.failureOf(StateError('a'), elsewhere)),
      );
    });
  });
}
