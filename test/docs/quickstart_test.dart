import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// The doc whose code and reports this test holds to what grit prints.
const String _quickstart = 'docs/quickstart.md';

/// A fenced block of markdown: its language, then its code.
final RegExp _fence = .new(
  r'^```(\w*)\n(.*?)^```',
  multiLine: true,
  dotAll: true,
);

/// A time a report prints, which turns on the clock.
final RegExp _time = .new(r'[\d.]+ (?:ms|µs|s)\b');

/// A count or a seed a report prints, which turns on the seed.
final RegExp _count = .new(r'\d+ steps|Seed \d+|seed: \d+');

/// The code of each block of [language] in [markdown], in order.
List<String> _blocks(String markdown, String language) => [
  for (final RegExpMatch fence in _fence.allMatches(markdown))
    if (fence[1] == language) fence[2]!,
];

/// [report] with each time and each count that varies from run to run
/// masked, since no page can quote them as they print on every run.
String _masked(String report) => report
    .replaceAll(_time, 'a time')
    .replaceAllMapped(
      _count,
      (Match match) => match[0]!.replaceAll(RegExp(r'\d+'), 'N'),
    );

/// The message of the one error a `dart test` run of [file] reported, its
/// stack trace aside.
///
/// The run's working directory is [file]'s own, so the failure its search
/// stores goes under that directory's `.dart_tool/grit/`, never the
/// package's.
Future<String> _reported(File file) async {
  final ProcessResult run = await Process.run(Platform.resolvedExecutable, [
    'test',
    '--reporter',
    'json',
    path.basename(file.path),
  ], workingDirectory: file.parent.path);
  final List<String> errors = [
    for (final String line in LineSplitter.split(run.stdout as String))
      if (jsonDecode(line) case {'type': 'error', 'error': final String error})
        error,
  ];
  expect(errors, hasLength(1), reason: '${run.stdout}${run.stderr}');
  return errors.single;
}

void main() {
  group('the quickstart', () {
    late final String markdown;
    late final List<String> dart;
    late final List<String> reports;
    late final Directory directory;

    setUpAll(() {
      markdown = File(_quickstart).readAsStringSync();
      dart = _blocks(markdown, 'dart');
      reports = _blocks(markdown, 'text');
      // Inside the package, so the page's file resolves package:grit, and
      // its store's files go with the directory.
      directory = .new('.dart_tool').createTempSync('quickstart_');
    });

    tearDownAll(() => directory.deleteSync(recursive: true));

    test('quotes the report its property prints on a search', () async {
      final File file = .new(path.join(directory.path, 'row_test.dart'))
        ..writeAsStringSync(dart[0]);
      expect(_masked(await _reported(file)), _masked(reports[0].trimRight()));
    });

    test('quotes the report its property prints on its token\'s replay', () async {
      // The page's file with its property replaced by the page's replay of it.
      final String property = dart[0].substring(
        dart[0].indexOf('  property('),
        dart[0].indexOf('  });\n') + '  });\n'.length,
      );
      final File file = .new(path.join(directory.path, 'replay_test.dart'))
        ..writeAsStringSync(dart[0].replaceFirst(property, dart[1]));
      expect(await _reported(file), reports[1].trimRight());
    });

    test('replays the token its search report prints', () {
      final String token = RegExp(r"replay: '([^']+)'")
          .firstMatch(reports[0])![1]!;
      expect(dart[1], contains("Settings(replay: '$token')"));
    });
  });
}
