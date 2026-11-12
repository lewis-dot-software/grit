@Tags(['lean'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:grit/grit.dart';
import 'package:grit/src/shrink/shrink.dart';
import 'package:test/test.dart';

import '../support/inputs.dart';
import '../support/lake.dart';
import '../support/oracle.dart';
import '../support/shrinking.dart';

/// The way shrinking went: each candidate proposed and the answer it was
/// told, in order, and the state it ended in.
typedef _Path = ({
  List<ChoiceSequence> candidates,
  List<bool> told,
  Shrunk end,
});

/// The path from shrinking [first] to its end, each candidate told as
/// failing as [oracle] answers it in turn.
_Path _path(ChoiceSequence first, Oracle oracle) {
  final List<ChoiceSequence> candidates = [];
  final List<bool> told = [];
  final Shrunk end = shrunk(.start(first), (ChoiceSequence candidate) {
    final bool failed = answerOf(oracle, told.length, candidate);
    candidates.add(candidate);
    told.add(failed);
    return failed;
  });
  return (candidates: candidates, told: told, end: end);
}

/// [sequence] written `[1,2]`, as the model writes it.
String _written(ChoiceSequence sequence) => '[${sequence.choices.join(',')}]';

/// The model's request to shrink [first], told [told] in turn.
String _request(ChoiceSequence first, List<bool> told) =>
    '${first.choices.join(',')}\t${[for (final bool failed in told) failed ? '1' : '0'].join()}';

/// What the model answers where it proposes each of [path]'s candidates and
/// ends where it does.
String _expected(_Path path) =>
    '${path.candidates.map(_written).join()}\tshrunk\t${_written(path.end.current)}';

/// Where [actual] first parts from [expected], as a few characters either
/// side of the place.
String _parting(String expected, String actual) {
  int at = 0;
  while (at < expected.length &&
      at < actual.length &&
      expected[at] == actual[at]) {
    at++;
  }
  String around(String text) => text.substring(
    (at - 40).clamp(0, text.length),
    (at + 40).clamp(0, text.length),
  );
  final int step = '['.allMatches(expected.substring(0, at)).length;
  return 'at candidate $step, the Dart ${around(expected)} '
      'and the model ${around(actual)}';
}

void main() {
  Process? model;
  late StreamIterator<String> answers;

  setUpAll(() async {
    final ProcessResult build = await Process.run(lake().path, [
      'build',
    ], workingDirectory: 'lean');
    if (build.exitCode != 0) {
      fail('lake build failed in lean/:\n${build.stdout}${build.stderr}');
    }
    final Process started = await Process.start(
      'lean/.lake/build/bin/shrink-model',
      [],
    );
    model = started;
    answers = .new(
      started.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
  });
  tearDownAll(() async {
    if (model case final Process running) {
      await running.stdin.close();
      await running.exitCode;
    }
  });

  Future<String> ask(String request) async {
    final Process running = model ?? fail('the model never started');
    running.stdin.writeln(request);
    if (!await answers.moveNext()) fail('the model closed its output');
    return answers.current;
  }

  property('Shrink proposes each candidate and ends as the Lean model does, '
      'whatever the oracle answers', (Draw draw) async {
    final ChoiceSequence first = draw(anySequence, label: 'first failure');
    final _Path path = _path(first, drawOracle(draw, first));
    final String expected = _expected(path);
    final String actual = await ask(_request(first, path.told));
    if (actual != expected) fail(_parting(expected, actual));
  }, settings: .new(runs: 1000));

  test('the Lean model refuses a request it cannot read, naming it', () async {
    for (final String request in ['1,x\t0', '1\t2', '1']) {
      expect(await ask(request), 'refused $request', reason: request);
    }
  });
}
