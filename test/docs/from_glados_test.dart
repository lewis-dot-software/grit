import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../support/code_span.dart';

/// The guide for a suite moving from glados.
const String _guide = 'docs/from-glados.md';

/// The names the generator table's grit cells stand in for a glados call's
/// own arguments, each to its type.
///
/// A bound is `Never`, which every parameter accepts, since a cell of
/// `.integer` takes an `int` and one of `.float` a `double`.
const Map<String, String> _placeholders = {
  'min': 'Never',
  'max': 'Never',
  'gen': 'Gen<int>',
  'gens': 'List<Gen<int>>',
  'a': 'Gen<int>',
  'b': 'Gen<int>',
  'values': 'List<int>',
  'chars': 'String',
  'combine': 'int Function(int, int)',
  'convert': 'int Function(int)',
};

/// The grit column of a generator table:
///
/// - `code`: the code spans of each cell made of one code span or more alone.
/// - `prose`: each other cell, an empty one among them, which names no
///   generator.
typedef _GritColumn = ({List<String> code, List<String> prose});

/// The grit column of [markdown]'s generator table, its header row and its
/// separator aside.
_GritColumn _gritColumn(String markdown) {
  final String section = markdown
      .split(RegExp(r'^## ', multiLine: true))
      .singleWhere((String part) => part.startsWith('Generators\n'));
  final List<String> cells = [
    for (final String row
        in section
            .split('\n')
            .where((String line) => line.startsWith('|'))
            .skip(2))
      row.split('|')[2].trim(),
  ];
  bool isCode(String cell) =>
      codeSpan.hasMatch(cell) &&
      cell.replaceAll(codeSpan, '').replaceAll(',', '').trim().isEmpty;
  return (
    code: [
      for (final String cell in cells.where(isCode))
        for (final RegExpMatch span in codeSpan.allMatches(cell)) span[1]!,
    ],
    prose: [...cells.where((String cell) => !isCode(cell))],
  );
}

/// The source of a function that draws [cell], its placeholders its
/// parameters.
String _drawing(String cell) =>
    '''
import 'package:grit/grit.dart';

void drawing(Draw draw, ${[for (final MapEntry(key: String name, value: String type) in _placeholders.entries) '$type $name'].join(', ')}) {
  draw($cell);
}
''';

/// The errors of each of [cells] drawn inside a function, keyed by cell, a
/// cell with none left out.
///
/// A cell that is not the one argument of one draw is an error of its own,
/// as is one typed `Never`, since a bound alone compiles inside a draw and
/// names no generator.
Future<Map<String, List<String>>> _compileErrors(List<String> cells) async {
  final OverlayResourceProvider files = .new(PhysicalResourceProvider.INSTANCE);
  // Inside the package, so each source resolves package:grit, and in the
  // overlay alone, so nothing is written.
  final Map<String, String> sources = {
    for (final (int index, String cell) in cells.indexed)
      path.normalize(path.absolute('test/docs/_cell_${index}_test.dart')): cell,
  };
  sources.forEach(
    (String source, String cell) =>
        files.setOverlay(source, content: _drawing(cell), modificationStamp: 0),
  );
  final AnalysisContextCollection collection = .new(
    includedPaths: [...sources.keys],
    resourceProvider: files,
  );

  final Map<String, List<String>> errors = {};
  for (final MapEntry(key: String source, value: String cell)
      in sources.entries) {
    final SomeResolvedUnitResult result = await collection
        .contextFor(source)
        .currentSession
        .getResolvedUnit(source);
    if (result is! ResolvedUnitResult) {
      throw StateError('The analyzer resolved no unit: $result');
    }
    final String? shape = switch (result.unit.declarations) {
      [
        FunctionDeclaration(
          functionExpression: FunctionExpression(
            body: BlockFunctionBody(
              block: Block(
                statements: [
                  ExpressionStatement(
                    expression: InvocationExpression(
                      argumentList: ArgumentList(
                        arguments: [final Expression argument],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ] =>
        argument.staticType is NeverType
            ? 'The cell draws a bound alone, typed Never, which names no '
                  'generator'
            : null,
      _ => 'The cell is not the one argument of one draw',
    };
    final List<String> messages = [
      for (final Diagnostic diagnostic in result.diagnostics)
        if (diagnostic.diagnosticCode.severity == .ERROR) diagnostic.message,
      ?shape,
    ];
    if (messages.isNotEmpty) errors[cell] = messages;
  }
  return errors;
}

void main() {
  test('a grit cell that names no generator is read as prose, so the pin '
      'of the guide fails on it', () {
    final (:List<String> code, :List<String> prose) = _gritColumn('''
## Generators

| glados | grit |
|---|---|
| `any.int` | `.integer()` |
| `any.bool` |  |
| `any.digits` | , |
''');
    expect(code, ['.integer()']);
    expect(prose, ['', ',']);
  });

  test('a grit cell that is a bound alone, or more than one draw, fails the '
      'compile', () async {
    expect(
      (await _compileErrors(['min', 'max', 'gen', 'gen); draw(gen'])).keys,
      ['min', 'max', 'gen); draw(gen'],
    );
  });

  test('the glados guide names, in each grit cell of its generator table, a '
      'generator that compiles inside a draw', () async {
    final (code: List<String> cells, :List<String> prose) = _gritColumn(
      File(_guide).readAsStringSync(),
    );
    // The table's first cell, so a reading of no cell fails.
    expect(cells, contains('.integer()'));
    // A cell that is not code, an empty one among them, is left out of the
    // compile, so the guide's one cell of prose is pinned as the only one.
    expect(prose, [
      "A draw of `next`'s generator on the value drawn before it",
    ]);

    expect(await _compileErrors(cells), isEmpty);
  });
}
