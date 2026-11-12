import 'package:grit/grit.dart';

import '../support/challenge.dart';

/// An expression of integers, their sums and their quotients.
sealed class _Expression {
  /// The expression's value, which throws where it divides by 0.
  int get value;

  /// Whether no quotient within the expression has a literal 0 as its
  /// divisor.
  bool get dividesByNoLiteralZero;
}

final class _Literal extends _Expression {
  _Literal(this.value);

  @override
  final int value;

  @override
  bool get dividesByNoLiteralZero => true;

  @override
  bool operator ==(Object other) => other is _Literal && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';
}

final class _Sum extends _Expression {
  _Sum(this.left, this.right);

  final _Expression left;
  final _Expression right;

  @override
  int get value => left.value + right.value;

  @override
  bool get dividesByNoLiteralZero =>
      left.dividesByNoLiteralZero && right.dividesByNoLiteralZero;

  @override
  bool operator ==(Object other) =>
      other is _Sum && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(_Sum, left, right);

  @override
  String toString() => "('+', $left, $right)";
}

final class _Quotient extends _Expression {
  _Quotient(this.left, this.right);

  final _Expression left;
  final _Expression right;

  @override
  int get value => left.value ~/ right.value;

  @override
  bool get dividesByNoLiteralZero =>
      right != _Literal(0) &&
      left.dividesByNoLiteralZero &&
      right.dividesByNoLiteralZero;

  @override
  bool operator ==(Object other) =>
      other is _Quotient && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(_Quotient, left, right);

  @override
  String toString() => "('/', $left, $right)";
}

/// The kinds of expression, the simplest first.
enum _Kind { literal, sum, quotient }

/// The kinds a node of an expression is drawn from, a literal three times in
/// five, as the challenge's source draws them, so an expression is finite.
const List<_Kind> _kinds = [.literal, .literal, .literal, .sum, .quotient];

/// An expression, its kind at each node drawn from [_kinds].
final Gen<_Expression> _expression = .build(
  (Draw draw) => switch (draw(.element(_kinds))) {
    .literal => _Literal(draw(.integer())),
    .sum => _Sum(draw(_expression), draw(_expression)),
    .quotient => _Quotient(draw(_expression), draw(_expression)),
  },
);

/// An expression with no quotient by a literal 0, under the false property
/// that it evaluates with no division by 0.
void main() {
  challenge('calculator', (Draw draw) {
    final _Expression expression = draw(_expression);
    draw.assume(expression.dividesByNoLiteralZero);
    expression.value;
  }, [_Quotient(_Literal(0), _Sum(_Literal(0), _Literal(0)))]);
}
