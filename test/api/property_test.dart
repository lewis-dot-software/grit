import 'dart:convert';
import 'dart:io';

import 'package:grit/grit.dart';
import 'package:test/test.dart';
import 'package:test_api/backend.dart' show Declarer, GroupEntry;

/// How one test of a `dart test` run ended.
///
/// - `result`: the reporter's result, `success`, `failure` or `error`.
/// - `skipped`: whether the test was skipped.
/// - `errors`: the message of each error the test reported, in order.
/// - `stackTraces`: the stack trace of each, in the same order.
typedef _Result = ({
  String result,
  bool skipped,
  List<String> errors,
  List<String> stackTraces,
});

/// The fixture's properties, each named for the outcome it comes to.
const String _fixture = 'fixture/properties_test.dart';

/// Each visible test of a `dart test` run of [path], by name.
Future<Map<String, _Result>> _results(String path) async {
  final ProcessResult run = await Process.run(Platform.resolvedExecutable, [
    'test',
    '--reporter',
    'json',
    '--exclude-tags',
    'tagged-out',
    path,
  ]);
  final Map<int, String> names = {};
  final Map<int, List<(String, String)>> errors = {};
  final Map<String, _Result> results = {};
  for (final String line in LineSplitter.split(run.stdout as String)) {
    switch (jsonDecode(line)) {
      case {
        'type': 'testStart',
        'test': {'id': final int id, 'name': final String name},
      }:
        names[id] = name;
      case {
        'type': 'error',
        'testID': final int id,
        'error': final String error,
        'stackTrace': final String stackTrace,
      }:
        (errors[id] ??= []).add((error, stackTrace));
      case {
        'type': 'testDone',
        'testID': final int id,
        'result': final String result,
        'skipped': final bool skipped,
        'hidden': false,
      }:
        final List<(String, String)> reported = errors[id] ?? [];
        results[names[id]!] = (
          result: result,
          skipped: skipped,
          errors: [for (final (String error, _) in reported) error],
          stackTraces: [for (final (_, String trace) in reported) trace],
        );
    }
  }
  return results;
}

void main() {
  late final Map<String, _Result> results;

  setUpAll(() async => results = await _results(_fixture));

  group('property', () {
    test('declares a test with no timeout', () {
      final Declarer declarer = .new();
      declarer.declare(() => property('declared', (Draw draw) {}));
      final GroupEntry declared = declarer.build().entries.single;
      expect(declared.metadata.timeout, Timeout.none);
    });

    test('fails a dart test run with its shrunk case in the message', () {
      final _Result fails = results['fails']!;
      expect(fails.result, 'failure');
      expect(
        fails.errors.single,
        allOf(
          startsWith('The property failed.'),
          contains('It drew:\n  xs: [10]\n'),
          contains('It noted:\n  sum 10\n'),
          contains('It threw:\n  Expected: a value less than <10>\n'),
          contains('Seed 1.'),
        ),
      );
    });

    test('points its failure at the line of the body that threw', () {
      expect(
        results['fails']!.stackTraces.single,
        matches(
          RegExp(
            r'^package:matcher +expect\nfixture/properties_test\.dart \d+:\d+ +main\.<fn>\n',
          ),
        ),
      );
    });

    test('passes a dart test run where its search passes', () {
      expect(results['passes']!.result, 'success');
    });

    test('fails a dart test run where its search gives up', () {
      final _Result givesUp = results['gives up']!;
      expect(givesUp.result, 'failure');
      expect(givesUp.errors.single, startsWith('The property gave up'));
    });

    test('fails a dart test run where its search is flaky', () {
      final _Result flaky = results['is flaky']!;
      expect(flaky.result, 'failure');
      expect(
        flaky.errors.single,
        allOf(
          startsWith('The property is flaky'),
          matches(
            RegExp(
              r'ArgumentError from file://\S*/fixture/properties_test\.dart:',
            ),
          ),
        ),
      );
    });

    group('takes test\'s own', () {
      test('skip', () {
        expect(results['is skipped']!.skipped, isTrue);
      });

      test('testOn', () {
        expect(results, isNot(contains('runs on the browser alone')));
      });

      test('tags', () {
        expect(results, isNot(contains('is tagged out')));
      });

      test('onPlatform', () {
        expect(results['is skipped on the VM']!.skipped, isTrue);
      });

      test('retry', () {
        expect(results['retried passes on its retry']!.result, 'success');
      });
    });

    test('draws a seed of its own for each search of a retry', () {
      final _Result retried = results['fails on each retry']!;
      expect(retried.result, 'failure');
      final Set<String?> seeds = {
        for (final String error in retried.errors)
          RegExp(r'Seed (\d+)\.').firstMatch(error)?[1],
      };
      expect(seeds, hasLength(2));
      expect(seeds, isNot(contains(null)));
    });
  });

  test('forAll fails the test that stands with its shrunk case', () {
    final _Result standing = results['fails inside a test that stands']!;
    expect(standing.result, 'failure');
    expect(standing.errors.single, contains('It drew:\n  b: true\n'));
  });
}
