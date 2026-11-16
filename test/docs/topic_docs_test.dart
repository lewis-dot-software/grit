import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// The doc that links every topic doc.
const String _quickstart = 'docs/quickstart.md';

/// One public entry `package:grit/grit.dart` exports:
///
/// - `name`: the declaration's name.
/// - `members`: the names of its own public members, its record fields where
///   it names a record type, and none where it is a function.
typedef _Entry = ({String name, Set<String> members});

/// The member names no doc need name: those every object has, and an
/// enum's list of its values.
const Set<String> _unnamed = {'==', 'hashCode', 'toString', 'values'};

/// Every public entry `package:grit/grit.dart` exports, read by the analyzer
/// from the library's export namespace, its `show` combinators applied.
Future<List<_Entry>> _exported() async {
  final String library = path.normalize(path.absolute('lib/grit.dart'));
  final AnalysisContextCollection collection = .new(includedPaths: [library]);
  final SomeLibraryElementResult result = await collection
      .contextFor(library)
      .currentSession
      .getLibraryByUri('package:grit/grit.dart');
  if (result is! LibraryElementResult) {
    throw StateError('The analyzer read no library: $result');
  }
  return [
    for (final MapEntry(key: String name, value: Element element)
        in result.element.exportNamespace.definedNames2.entries)
      (name: name, members: _members(element)),
  ];
}

/// The names of [element]'s own public members a consumer reaches, less
/// those [_unnamed] holds and those marked `@internal`, whose field or
/// getter alone may carry the mark.
///
/// An entry of a kind this reading does not know throws, so a new kind of
/// export is read before any doc is held to it.
Set<String> _members(Element element) {
  switch (element) {
    case InstanceElement():
      final List<Element> members = [
        ...element.fields,
        ...element.getters,
        ...element.methods,
        if (element is InterfaceElement) ...element.constructors,
      ];
      final Set<String?> internal = {
        for (final Element member in members)
          if (member.metadata.hasInternal) member.name,
      };
      return {
        for (final Element member in members)
          if (member.name case final String name
              when member.isPublic &&
                  name != 'new' &&
                  !_unnamed.contains(name) &&
                  !internal.contains(name))
            name,
      };
    case TypeAliasElement(aliasedType: RecordType(:final namedFields)):
      return {for (final RecordTypeNamedField field in namedFields) field.name};
    case TypeAliasElement() || TopLevelFunctionElement():
      return {};
    default:
      throw StateError('An export of an unread kind: $element');
  }
}

/// The relative paths of the docs [markdown] links, beside [from].
Set<String> _linkedDocs(String markdown, {required String from}) => {
  for (final RegExpMatch link in RegExp(
    r'\]\(([\w./-]+\.md)\)',
  ).allMatches(markdown))
    path.normalize(path.join(path.dirname(from), link[1]!)),
};

/// A fenced block of markdown, its code captured.
final RegExp _fence = .new(
  r'^```[^\n]*\n(.*?)^```',
  multiLine: true,
  dotAll: true,
);

/// A code span of markdown outside a fenced block, its code captured.
final RegExp _span = .new(r'`([^`\n]+)`');

/// An identifier of Dart's.
final RegExp _identifier = .new(r'[A-Za-z_$][\w$]*');

/// Every identifier inside a code span or a fenced block of [markdown].
Set<String> _codeIdentifiers(String markdown) {
  final Iterable<String> code = [
    for (final RegExpMatch fence in _fence.allMatches(markdown)) fence[1]!,
    for (final RegExpMatch span in _span.allMatches(
      markdown.replaceAll(_fence, ''),
    ))
      span[1]!,
  ];
  return {
    for (final String text in code)
      for (final RegExpMatch word in _identifier.allMatches(text)) word[0]!,
  };
}

void main() {
  group('the topic docs', () {
    late final Set<String> topics;
    late final Map<String, Set<String>> identifiers;
    late final List<_Entry> exported;

    setUpAll(() async {
      topics = _linkedDocs(
        File(_quickstart).readAsStringSync(),
        from: _quickstart,
      );
      identifiers = {
        for (final String topic in topics)
          if (File(topic).existsSync())
            topic: _codeIdentifiers(File(topic).readAsStringSync()),
      };
      exported = await _exported();
    });

    test('are each a doc that stands, linked from the quickstart', () {
      expect(topics, isNotEmpty);
      expect(identifiers.keys, unorderedEquals(topics));
    });

    test('name every public entry grit exports in code', () {
      // Draw is exported, so a reading of no entry fails.
      expect(exported.map((_Entry entry) => entry.name), contains('Draw'));
      expect([
        for (final _Entry entry in exported)
          if (!identifiers.values.any(
            (Set<String> words) => words.contains(entry.name),
          ))
            entry.name,
      ], isEmpty);
    });

    test('name each member of an entry in code, in a doc that names the '
        'entry', () {
      // Gen.integer is exported, so a reading of no member fails.
      expect(
        exported.singleWhere((_Entry entry) => entry.name == 'Gen').members,
        contains('integer'),
      );
      expect([
        for (final (:String name, :Set<String> members) in exported)
          for (final String member in members)
            if (!identifiers.values.any(
              (Set<String> words) =>
                  words.contains(name) && words.contains(member),
            ))
              '$name.$member',
      ], isEmpty);
    });
  });
}
