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

/// A declaration a library exports:
///
/// - `library`: the library it is declared in.
/// - `declaration`: the declaration.
typedef _Exported = ({LibraryMirror library, DeclarationMirror declaration});

/// A value a library exports without a call:
///
/// - `name`: its name, a class's static member's under its class's.
/// - `value`: the value.
typedef _Value = ({String name, Object? value});

/// Every public declaration `package:grit/grit.dart` exports, with the
/// library it is declared in, past each export's combinators.
Iterable<_Exported> get _exported sync* {
  final LibraryMirror grit =
      currentMirrorSystem().libraries[Uri.parse('package:grit/grit.dart')]!;
  for (final LibraryDependencyMirror export in grit.libraryDependencies) {
    if (!export.isExport) continue;
    final LibraryMirror library = export.targetLibrary!;
    for (final DeclarationMirror declaration in library.declarations.values) {
      if (!declaration.isPrivate &&
          _passes(export.combinators, declaration.simpleName)) {
        yield (library: library, declaration: declaration);
      }
    }
  }
}

/// Every class `package:grit/grit.dart` exports.
Iterable<ClassMirror> get _exportedClasses => [
  for (final (:DeclarationMirror declaration, library: _) in _exported)
    if (declaration is ClassMirror) declaration,
];

/// Every value `package:grit/grit.dart` exports without a call, by name: each
/// top-level variable and getter, an extension type's static members among
/// them as the VM lowers them, and each static field and getter of every
/// class.
Iterable<_Value> get _exportedValues sync* {
  for (final (:LibraryMirror library, :DeclarationMirror declaration)
      in _exported) {
    if (_isValue(declaration)) {
      yield (
        name: MirrorSystem.getName(declaration.simpleName),
        value: library.getField(declaration.simpleName).reflectee,
      );
    } else if (declaration is ClassMirror) {
      for (final DeclarationMirror member in declaration.declarations.values) {
        if (member.isPrivate || !_isStaticValue(member)) continue;
        yield (
          name:
              '${MirrorSystem.getName(declaration.simpleName)}.'
              '${MirrorSystem.getName(member.simpleName)}',
          value: declaration.getField(member.simpleName).reflectee,
        );
      }
    }
  }
}

/// Whether [declaration] is a variable or a getter, read without a call.
bool _isValue(DeclarationMirror declaration) =>
    declaration is VariableMirror ||
    (declaration is MethodMirror && declaration.isGetter);

/// Whether [member] is a static variable or getter of its class.
bool _isStaticValue(DeclarationMirror member) => switch (member) {
  VariableMirror(:final bool isStatic) => isStatic,
  MethodMirror(:final bool isGetter, :final bool isStatic) =>
    isGetter && isStatic,
  _ => false,
};

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
      final List<String> read = [];
      final List<String> empty = [];
      for (final (:String name, :Object? value) in _exportedValues) {
        read.add(name);
        if (value is ChoiceSequence && value.choices.isEmpty) empty.add(name);
      }
      // Alphabet.digits is exported, so a reading of no value fails.
      expect(read, contains('Alphabet.digits'));
      expect(empty, isEmpty);
    });
  });
}
