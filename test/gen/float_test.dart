import 'package:grit/grit.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/status.dart';
import 'package:grit/src/engine/search.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

import '../support/doubles.dart';
import '../support/draw_from.dart';
import '../support/drawing.dart';
import '../support/fake_clock.dart';
import '../support/memory_store.dart';
import '../support/small.dart';

/// A float's bounds and flags, as `Gen.float` takes them.
///
/// - `min`: the minimum, inclusive.
/// - `max`: the maximum, inclusive.
/// - `nan`: whether NaN is drawn, or null for the default.
/// - `infinite`: whether an infinity at a bound is drawn.
typedef _Range = ({double min, double max, bool? nan, bool infinite});

/// The generator of [range].
Gen<double> _genOf(_Range range) => .float(
  min: range.min,
  max: range.max,
  nan: range.nan,
  infinite: range.infinite,
);

/// Whether [range] allows NaN: where its flag says, and by default where it
/// runs from negative infinity to positive infinity.
bool _allowsNan(_Range range) =>
    range.nan ?? (range.min == .negativeInfinity && range.max == .infinity);

/// Whether [range] allows [value]: NaN only where its flag does, an infinity
/// only at an infinite bound where its flag allows one, and otherwise a
/// double within its bounds, -0.0 below 0.0.
bool _allows(_Range range, double value) {
  if (value.isNaN) return _allowsNan(range);
  if (value.isInfinite) {
    return range.infinite &&
        (value.isNegative ? range.min : range.max) == value;
  }
  return range.min.compareTo(value) <= 0 && value.compareTo(range.max) <= 0;
}

/// Whether [range] allows any double, so `Gen.float` takes it.
bool _holdsAny(_Range range) =>
    range.infinite ||
    _allowsNan(range) ||
    !(range.min == range.max && range.min.isInfinite);

/// Which of the kinds the simplicity order ranks first a double is: finite
/// of positive sign, finite of negative sign, or an infinity or NaN.
enum _Kind { positive, negative, nonfinite }

_Kind _kindOf(double value) =>
    !value.isFinite ? .nonfinite : (value.isNegative ? .negative : .positive);

/// Negative where [a] is simpler than [b], positive where it is less simple,
/// and 0 where they are the same double or neither is finite: the positive
/// before the negative, then a whole number before a fraction, then the
/// smaller magnitude before the larger.
int _simplicity(double a, double b) {
  final _Kind kindA = _kindOf(a);
  final _Kind kindB = _kindOf(b);
  if (kindA != kindB) return kindA.index.compareTo(kindB.index);
  if (kindA == .nonfinite) return 0;
  final bool wholeA = a == a.truncateToDouble();
  final bool wholeB = b == b.truncateToDouble();
  if (wholeA != wholeB) return wholeA ? -1 : 1;
  return a.abs().compareTo(b.abs());
}

/// The value [gen] draws from [choices], or null where the choices stop it.
double? _drawn(Gen<double> gen, List<int> choices) =>
    switch (drawFrom(gen, sequenceOf(choices))) {
      Drew(:final double value) => value,
      Stopped() => null,
    };

/// A float's bounds:
///
/// - `min`: its minimum.
/// - `max`: its maximum.
typedef _Bounds = ({double min, double max});

/// Each range the exhaustive checks cover, at each set of flags it holds a
/// double at.
final List<_Range> _ranges = [
  for (final (:double min, :double max) in <_Bounds>[
    (min: .negativeInfinity, max: .infinity),
    (min: 0, max: .infinity),
    (min: .negativeInfinity, max: 0),
    (min: .negativeInfinity, max: -0.0),
    (min: 0, max: 0),
    (min: -0.0, max: 0),
    (min: -0.0, max: -0.0),
    (min: 0.5, max: 3.25),
    (min: -3.25, max: -0.5),
    (min: -2.5, max: 1.5),
    (min: 0.25, max: 0.75),
    (min: 1e300, max: .infinity),
    (min: .negativeInfinity, max: -double.maxFinite),
    (min: .infinity, max: .infinity),
    (min: .negativeInfinity, max: .negativeInfinity),
    (min: -3 * .minPositive, max: 2 * .minPositive),
    (min: 4503599627370494.5, max: 4503599627370497),
    (min: 9007199254740990, max: 9007199254740996),
  ])
    for (final bool? nan in [null, true, false])
      for (final bool infinite in [true, false])
        if ((min: min, max: max, nan: nan, infinite: infinite)
            case final _Range range when _holdsAny(range))
          range,
];

/// Choices of a float's magnitude at each seam its encoding turns on: the
/// small whole numbers, those past which wholes thin out and fractions
/// begin, and the largest choice there is.
final List<int> _magnitudeChoices = [
  for (int c = 0; c <= 8; c++) c,
  for (final int seam in [
    1 << 52,
    1 << 53,
    973 << 52,
    (973 << 52) + (1023 << 52),
    2047 << 52,
  ]) ...[seam - 1, seam, seam + 1],
  Choice.largest.value,
];

/// Every sequence of a choice of part up to 5 and one of [_magnitudeChoices].
final List<List<int>> _sequences = [
  for (int part = 0; part <= 5; part++)
    for (final int magnitude in _magnitudeChoices) [part, magnitude],
];

/// Ranges holding few enough doubles that every one is counted, each at
/// every set of flags.
final List<_Range> _narrow = [
  for (final _Range range in _ranges)
    if (range.min.isFinite || range.max.isFinite)
      if (_count(range) <= 16) range,
];

/// How many finite doubles lie from [range]'s minimum to its maximum, up to
/// 17.
int _count(_Range range) {
  int count = 0;
  for (
    double x = range.min.isFinite ? range.min : -double.maxFinite;
    x.compareTo(range.max) <= 0 && x.isFinite && count <= 16;
    x = nextUp(x)
  ) {
    count++;
  }
  return count;
}

/// Every double [range] allows, each once.
List<double> _everyAllowed(_Range range) => [
  for (
    double x = range.min.isFinite ? range.min : -double.maxFinite;
    x.compareTo(range.max) <= 0 && x.isFinite;
    x = nextUp(x)
  )
    x,
  if (range.infinite && range.max == .infinity) .infinity,
  if (range.infinite && range.min == .negativeInfinity) .negativeInfinity,
  if (_allowsNan(range)) .nan,
];

/// A range of two doubles short of NaN, in order, at drawn flags.
final Gen<_Range> _anyRange = .build((Draw draw) {
  final double a = draw(anyDouble.filter((double x) => !x.isNaN));
  final double b = draw(anyDouble.filter((double x) => !x.isNaN));
  final bool? nan = draw(.element([null, true, false]));
  final _Range range = (
    min: a.compareTo(b) <= 0 ? a : b,
    max: a.compareTo(b) <= 0 ? b : a,
    nan: nan,
    infinite: draw(.boolean()),
  );
  draw.assume(_holdsAny(range));
  return range;
});

/// The choices of a float: a part from 0 to 5, and a magnitude at a seam or
/// anywhere.
final Gen<List<int>> _anyChoices = .build(
  (Draw draw) => [
    draw(.integer(min: 0, max: 5)),
    draw(
      .oneOf([
        .element(_magnitudeChoices),
        .integer(min: 0, max: Choice.largest.value),
      ]),
    ),
  ],
);

/// The choices from which [gen] draws [target], found by the order the
/// float's docs give: its part by trying each, then its magnitude by binary
/// search, or null where no choices draw it.
List<int>? _choicesOf(Gen<double> gen, double target) {
  for (int part = 0; ; part++) {
    final double? first = _drawn(gen, [part, 0]);
    if (first == null) return null;
    if (_kindOf(first) != _kindOf(target)) continue;
    if (_kindOf(target) == .nonfinite) {
      if (sameDouble(first, target)) return [part, 0];
      continue;
    }
    // The smallest choice drawing a double no simpler than the target, or a
    // stop past the part's bound.
    int low = 0;
    int high = Choice.largest.value;
    while (low < high) {
      final int middle = low + (high - low) ~/ 2;
      final double? value = _drawn(gen, [part, middle]);
      if (value == null || _simplicity(value, target) >= 0) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    final double? found = _drawn(gen, [part, low]);
    return found != null && sameDouble(found, target) ? [part, low] : null;
  }
}

/// Fails the test where [choices] draws from [range] a double it does not
/// allow.
void _expectAllowed(_Range range, List<int> choices) {
  if (_drawn(_genOf(range), choices) case final double value) {
    expect(
      _allows(range, value),
      isTrue,
      reason: '$range: $choices drew $value',
    );
  }
}

/// Fails the test where the smaller of [a] and [b] draws from [range] the
/// less simple double, or where two choices draw the same one.
void _expectOrdered(_Range range, List<int> a, List<int> b) {
  final Gen<double> gen = _genOf(range);
  final double? x = _drawn(gen, a);
  final double? y = _drawn(gen, b);
  if (x == null || y == null) return;
  final int order = sequenceOf(a).compareTo(sequenceOf(b));
  if (order == 0) return;
  final double simpler = order < 0 ? x : y;
  final double other = order < 0 ? y : x;
  final String reason = '$range: $a drew $x, $b drew $y';
  expect(sameDouble(simpler, other), isFalse, reason: reason);
  if (_kindOf(simpler) == .nonfinite && _kindOf(other) == .nonfinite) return;
  expect(_simplicity(simpler, other), lessThan(0), reason: reason);
}

/// The choices of the form [gen]'s draw from [choices] names, or null where
/// it names none or the choices stop it.
List<int>? _formOf(Gen<double> gen, List<int> choices) {
  final ChoiceSource source = .fixed(sequenceOf(choices));
  final RunDraw draw = .new(source);
  if (run(source, () => draw(gen)) != .returned) return null;
  return switch (draw.spans.single.form) {
    final ChoiceSequence form => [
      for (final Choice choice in form.choices) choice.value,
    ],
    null => null,
  };
}

/// The whole number [range]'s float [value] names as its form: for a
/// fraction, the whole number of its sign at its magnitude rounded up, and
/// for an infinity, the finite double of its sign of the largest magnitude,
/// each where [range] allows it, and null otherwise.
double? _formWhole(_Range range, double value) {
  if (value.isNaN || value.isFinite && value == value.truncateToDouble()) {
    return null;
  }
  final double whole = value.isInfinite
      ? (value.isNegative ? -double.maxFinite : .maxFinite)
      : (value.isNegative ? -1 : 1) * value.abs().ceilToDouble();
  return range.min.compareTo(whole) <= 0 && whole.compareTo(range.max) <= 0
      ? whole
      : null;
}

/// Fails the test where the float [choices] draws from [range] names a form
/// other than its [_formWhole], or one that is no smaller than [choices].
void _expectForm(_Range range, List<int> choices) {
  final Gen<double> gen = _genOf(range);
  final double? value = _drawn(gen, choices);
  if (value == null) return;
  final List<int>? form = _formOf(gen, choices);
  final String reason = '$range: $choices drew $value and named $form';
  switch (_formWhole(range, value)) {
    case final double whole:
      expect(form, isNotNull, reason: reason);
      expect(sameDouble(_drawn(gen, form!)!, whole), isTrue, reason: reason);
      expect(
        sequenceOf(form).isSmallerThan(sequenceOf(choices)),
        isTrue,
        reason: reason,
      );
    case null:
      expect(form, isNull, reason: reason);
  }
}

void main() {
  test('GEN-17: Every float drawn: is NaN only where its `nan` flag '
      'allows it, infinite only where its bounds and `infinite` flag '
      'allow it, and otherwise lies within its bounds.', () {
    for (final _Range range in _ranges) {
      for (final List<int> choices in _sequences) {
        _expectAllowed(range, choices);
      }
    }
  });

  test('GEN-18: Every float its bounds and flags allow is drawn by some '
      'sequence.', () {
    expect(_narrow, isNotEmpty);
    for (final _Range range in _narrow) {
      final List<double> allowed = _everyAllowed(range);
      final Gen<double> gen = _genOf(range);
      final List<double> drawn = [
        for (int part = 0; part <= 5; part++)
          for (int magnitude = 0; magnitude <= 17; magnitude++)
            ?_drawn(gen, [part, magnitude]),
      ];
      final String reason = '$range: drew $drawn';
      for (final double value in allowed) {
        expect(
          drawn.any((double x) => sameDouble(x, value)),
          isTrue,
          reason: reason,
        );
      }
      // Each sequence draws a double of its own.
      expect(drawn, hasLength(allowed.length), reason: reason);
    }
    for (final _Range range in _ranges) {
      for (final double target in seams) {
        if (!_allows(range, target)) continue;
        expect(
          _choicesOf(_genOf(range), target),
          isNotNull,
          reason: '$range: $target',
        );
      }
    }
  });

  test('GEN-19: Of two floats in range, the simpler is drawn by the '
      'smaller sequence: the positive before the negative, then a '
      'whole number before a fraction, then the smaller magnitude '
      'before the larger, with the infinities and NaN after every '
      'finite float.', () {
    // The sequences run in shortlex order, and the order of simplicity is
    // transitive, so each pair beside each other stands for every pair.
    for (final _Range range in _ranges) {
      final List<List<int>> drawing = [
        for (final List<int> choices in _sequences)
          if (_drawn(_genOf(range), choices) != null) choices,
      ];
      for (int i = 1; i < drawing.length; i++) {
        expect(
          sequenceOf(drawing[i - 1]).isSmallerThan(sequenceOf(drawing[i])),
          isTrue,
        );
        _expectOrdered(range, drawing[i - 1], drawing[i]);
      }
    }
  });

  test('GEN-20: A float names a form, where the range holds it and by a '
      'smaller sequence, as follows: a fraction names the whole '
      'number of its sign at its magnitude rounded up, an infinity '
      'names the finite double of its sign of the largest magnitude, '
      'no other float names one.', () {
    for (final _Range range in _ranges) {
      for (final List<int> choices in _sequences) {
        _expectForm(range, choices);
      }
    }
  });

  test(
    'draws 0.0 first where unbounded, and each part\'s doubles in order',
    () {
      final Gen<double> gen = .float();
      expect(
        [
          for (final List<int> choices in [
            [0, 0],
            [0, 1],
            [0, 9007199254740992],
            [0, (973 << 52) - 1],
            [0, 973 << 52],
            [0, (2047 << 52) - 1],
            [1, 0],
            [1, 1],
            [2, 0],
            [3, 0],
            [4, 0],
          ])
            '${_drawn(gen, choices)}',
        ],
        [
          '0.0',
          '1.0',
          '9007199254740992.0',
          '1.7976931348623157e+308',
          '5e-324',
          '4503599627370495.5',
          '-0.0',
          '-1.0',
          'Infinity',
          '-Infinity',
          'NaN',
        ],
      );
    },
  );

  test('draws a bounded range\'s whole numbers first, then its fractions, '
      'each from its smallest magnitude', () {
    final Gen<double> gen = .float(min: 0.5, max: 3.25);
    expect(
      [
        for (int c = 0; c <= 4; c++) _drawn(gen, [0, c]),
      ],
      [1.0, 2.0, 3.0, 0.5, 0.5000000000000001],
    );
    expect(_drawn(.float(min: -3.25, max: -0.5), [0, 0]), -1.0);
    expect(_drawn(.float(min: 0.25, max: 0.75), [0, 0]), 0.25);
  });

  test('names as a fraction\'s form the whole number of its sign at its '
      'magnitude rounded up, and as an infinity\'s the finite double of its '
      'sign of the largest magnitude, each where the range holds it', () {
    double? named(Gen<double> gen, double value) =>
        switch (_formOf(gen, _choicesOf(gen, value)!)) {
          final List<int> form => _drawn(gen, form),
          null => null,
        };
    final Gen<double> gen = .float();
    expect(
      [
        for (final double value in [
          0.5,
          -2.5,
          4503599627370495.5,
          .infinity,
          .negativeInfinity,
          3,
          -0.0,
          .nan,
        ])
          named(gen, value),
      ],
      [
        1.0,
        -3.0,
        4503599627370496.0,
        double.maxFinite,
        -double.maxFinite,
        null,
        null,
        null,
      ],
    );
    final Gen<double> bounded = .float(min: 0.5, max: 3.25);
    expect(named(bounded, 0.75), 1.0);
    expect(named(bounded, 3.25), isNull);
  });

  test('rejects a choice past a part\'s bound, and past the last part', () {
    final Gen<double> gen = .float();
    expect(
      (drawFrom(gen, sequenceOf([0, 2047 << 52])) as Stopped<double>).status,
      Status.rejected,
    );
    expect(
      (drawFrom(gen, sequenceOf([2, 1])) as Stopped<double>).status,
      Status.rejected,
    );
    expect(
      (drawFrom(gen, sequenceOf([5, 0])) as Stopped<double>).status,
      Status.rejected,
    );
  });

  test('draws NaN from a bounded range only where its flag is set, and from '
      'an unbounded one unless its flag is cleared', () {
    bool drawsNan(Gen<double> gen) => [
      for (int part = 0; part <= 4; part++) _drawn(gen, [part, 0]),
    ].any((double? x) => x != null && x.isNaN);
    expect(drawsNan(.float()), isTrue);
    expect(drawsNan(.float(nan: false)), isFalse);
    expect(drawsNan(.float(min: 0)), isFalse);
    expect(drawsNan(.float(min: 0, nan: true)), isTrue);
    expect(drawsNan(.float(min: 0, max: 1, nan: true)), isTrue);
  });

  test('a range from 0.0 holds no -0.0, and one from -0.0 does', () {
    final List<double?> fromZero = [
      for (int part = 0; part <= 4; part++) _drawn(.float(min: 0), [part, 0]),
    ];
    expect(
      fromZero.whereType<double>().any((double x) => x.isNegative),
      isFalse,
    );
    expect(
      sameDouble(_drawn(.float(min: -0.0, max: 0), [1, 0])!, -0.0),
      isTrue,
    );
  });

  test('draws -0.0, both infinities, NaN, and the smallest subnormal and '
      'largest finite double of each sign, from a random fill at edges of '
      '1', () {
    final ChoiceSource source = .random(.new(0), limit: 4000, edges: .new(1));
    final RunDraw draw = .new(source);
    final List<double> drawn = [for (int i = 0; i < 1000; i++) draw(.float())];
    for (final double edge in [
      -0.0,
      .infinity,
      .negativeInfinity,
      .nan,
      .minPositive,
      -double.minPositive,
      .maxFinite,
      -double.maxFinite,
    ]) {
      expect(
        drawn.any((double x) => sameDouble(x, edge)),
        isTrue,
        reason: '$edge',
      );
    }
  });

  test('A search from each of seeds 0 to 9 draws -0.0, both infinities and '
      'NaN from an unbounded float within its early runs.', () async {
    for (int seed = 0; seed < 10; seed++) {
      final List<double> early = [];
      int run = 0;
      await Search(
        clock: FakeClock(),
        random: .new(seed),
        callSite: .of(.current),
        store: MemoryStore(),
        runs: 100,
        limit: 24,
        invalid: 100,
        budget: .new(steps: 0, time: .zero),
        expectedRunTime: .zero,
      ).run((Draw draw) {
        final double x = draw(.float());
        if (run++ < 20) early.add(x);
      });
      for (final double edge in [-0.0, .infinity, .negativeInfinity, .nan]) {
        expect(
          early.any((double x) => sameDouble(x, edge)),
          isTrue,
          reason: 'seed $seed: $edge',
        );
      }
    }
  });

  group('a consumer\'s mistake', () {
    test('a bound of NaN is thrown', () {
      expect(() => Gen.float(min: .nan), throwsArgumentError);
      expect(() => Gen.float(max: .nan), throwsArgumentError);
    });

    test('a minimum above the maximum is thrown, 0.0 above -0.0', () {
      expect(() => Gen.float(min: 1, max: 0), throwsArgumentError);
      expect(() => Gen.float(min: 0, max: -0.0), throwsArgumentError);
    });

    test('a range holding no double its flags allow is thrown, saying '
        'neither an infinity nor NaN is allowed', () {
      for (final (:double min, :double max) in <_Bounds>[
        (min: .infinity, max: .infinity),
        (min: .negativeInfinity, max: .negativeInfinity),
      ]) {
        expect(
          () => Gen.float(min: min, max: max, infinite: false),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'No float lies from $min to $max where neither an infinity nor '
                  'NaN is allowed',
            ),
          ),
        );
      }
    });
  });

  group('on grit, over larger inputs', () {
    property('GEN-17: Every float drawn: is NaN only where its `nan` '
        'flag allows it, infinite only where its bounds and '
        '`infinite` flag allow it, and otherwise lies within its '
        'bounds.', (Draw draw) {
      _expectAllowed(
        draw(_anyRange, label: 'range'),
        draw(_anyChoices, label: 'choices'),
      );
    });

    property('GEN-18: Every float its bounds and flags allow is drawn by '
        'some sequence.', (Draw draw) {
      final double target = draw(anyDouble, label: 'target');
      final double a = draw(anyDouble.filter((double x) => !x.isNaN));
      final double b = draw(anyDouble.filter((double x) => !x.isNaN));
      final double low = a.compareTo(b) <= 0 ? a : b;
      final double high = a.compareTo(b) <= 0 ? b : a;
      // The bounds widened to the target where it lies past them, so the
      // range holds it.
      final _Range range = (
        min: !target.isNaN && target.compareTo(low) < 0 ? target : low,
        max: !target.isNaN && target.compareTo(high) > 0 ? target : high,
        nan: target.isNaN ? true : draw(.element([null, true, false])),
        infinite: target.isInfinite || draw(.boolean()),
      );
      draw.note('range: $range');
      expect(_choicesOf(_genOf(range), target), isNotNull);
    });

    property('GEN-19: Of two floats in range, the simpler is drawn by '
        'the smaller sequence: the positive before the negative, then '
        'a whole number before a fraction, then the smaller magnitude '
        'before the larger, with the infinities and NaN after every '
        'finite float.', (Draw draw) {
      _expectOrdered(
        draw(_anyRange, label: 'range'),
        draw(_anyChoices, label: 'choices'),
        draw(_anyChoices, label: 'other choices'),
      );
    });

    property('GEN-20: A float names a form, where the range holds it and '
        'by a smaller sequence, as follows: a fraction names the '
        'whole number of its sign at its magnitude rounded up, an '
        'infinity names the finite double of its sign of the largest '
        'magnitude, no other float names one.', (Draw draw) {
      _expectForm(
        draw(_anyRange, label: 'range'),
        draw(_anyChoices, label: 'choices'),
      );
    });
  });
}
