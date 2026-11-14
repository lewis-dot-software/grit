import 'dart:mirrors';

import 'package:grit/grit.dart';
import 'package:test/test.dart';

/// The public names [type] declares itself, its constructors among them.
Set<String> _declared(Type type) => {
  for (final DeclarationMirror declaration in reflectClass(
    type,
  ).declarations.values)
    if (!declaration.isPrivate) MirrorSystem.getName(declaration.simpleName),
};

/// Every class `package:grit/grit.dart` exports, past each export's
/// combinators.
Iterable<ClassMirror> get _exportedClasses sync* {
  final LibraryMirror grit =
      currentMirrorSystem().libraries[Uri.parse('package:grit/grit.dart')]!;
  for (final LibraryDependencyMirror export in grit.libraryDependencies) {
    if (!export.isExport) continue;
    for (final DeclarationMirror declaration
        in export.targetLibrary!.declarations.values) {
      if (declaration is ClassMirror &&
          !declaration.isPrivate &&
          _passes(export.combinators, declaration.simpleName)) {
        yield declaration;
      }
    }
  }
}

/// Whether [name] passes [combinators]: shown by one where any shows, and
/// hidden by none.
///
/// The VM's mirrors give a `show` of several names as one combinator per name,
/// so the names shown are the union of every `show`'s.
bool _passes(List<CombinatorMirror> combinators, Symbol name) {
  final List<CombinatorMirror> shows = [
    for (final CombinatorMirror combinator in combinators)
      if (combinator.isShow) combinator,
  ];
  return (shows.isEmpty ||
          shows.any(
            (CombinatorMirror show) => show.identifiers.contains(name),
          )) &&
      !combinators.any(
        (CombinatorMirror combinator) =>
            combinator.isHide && combinator.identifiers.contains(name),
      );
}

void main() {
  group('the public library', () {
    test('lets a consumer call a draw, assume and note, and nothing else of '
        'a draw', () {
      expect(_declared(Draw), {'call', 'assume', 'note'});
    });

    test('exports no class that makes a draw', () {
      final ClassMirror draw = reflectClass(Draw);
      // Draw is exported, so a reading of no class fails.
      expect(_exportedClasses, contains(draw));
      expect([
        for (final ClassMirror exported in _exportedClasses)
          if (exported != draw && exported.isSubclassOf(draw))
            MirrorSystem.getName(exported.simpleName),
      ], isEmpty);
    });

    test('exports no empty choice sequence', () {
      // It holds a name the class does declare, so an empty reading fails.
      expect(
        _declared(ChoiceSequence),
        allOf(contains('isSmallerThan'), isNot(contains('empty'))),
      );
    });
  });
}
