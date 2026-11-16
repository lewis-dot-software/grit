import 'package:grit/grit.dart';

import 'threw.dart';

/// A run that threw a [StateError] from line 7 of a test.
final Threw _threw = threw();

/// The record [_threw] ran on.
final ChoiceSequence _record = _threw.record;

/// A run that did not throw: returned, rejected or overrun.
final Gen<Run> _notThrown = .element([
  Returned(_record, const [], const []),
  Rejected(_record, const [], const []),
  Overran(_record, const [], const []),
]);

/// A replay that did not fail as [_threw] did.
final Gen<Run> _replay = .oneOf([
  _notThrown,
  .element([threwOtherwise]),
]);

/// A warning of each kind.
final Gen<Warning> _warning = .oneOf([
  .build(
    (Draw draw) => SlowProperty(
      perRun: .new(microseconds: draw(.integer(min: 0, max: 1 << 30))),
      runs: draw(.integer(min: 1, max: 1 << 20)),
    ),
  ),
  .build(
    (Draw draw) => MostlyInvalid(
      returned: draw(.integer(min: 0, max: 1000)),
      rejected: draw(.integer(min: 0, max: 1000)),
      overran: draw(.integer(min: 0, max: 1000)),
    ),
  ),
  .element([
    UnreadableStored(NotAToken()),
    UnreadableStored(OtherFormat('grit0')),
  ]),
]);

/// Up to three warnings, in a list its outcome is handed growable.
final Gen<List<Warning>> _warnings = .list(_warning, maxLength: 3);

/// Where a failure was first found.
final Gen<FirstFound> _firstFound = .element(FirstFound.values);

/// An outcome of each kind, a failed or flaky one first found either way,
/// and a search's warning of up to three warnings.
final Gen<Outcome> outcomes = .oneOf([
  .build(
    (Draw draw) => Passed(
      runs: draw(.integer(min: 0, max: 1000)),
      warnings: draw(_warnings),
    ),
  ),
  .build(
    (Draw draw) => Failed(
      _record,
      _threw,
      firstFound: draw(_firstFound),
      steps: draw(.integer(min: 0, max: 5000)),
      time: .new(microseconds: draw(.integer(min: 0, max: 1 << 30))),
      end: draw(.element(ShrinkEnd.values)),
      warnings: draw(_warnings),
    ),
  ),
  .build(
    (Draw draw) => Flaky(
      _threw,
      draw(_replay),
      firstFound: draw(_firstFound),
      warnings: draw(_warnings),
    ),
  ),
  .build(
    (Draw draw) => GaveUp(
      rejected: draw(.integer(min: 0, max: 1000)),
      overran: draw(.integer(min: 0, max: 1000)),
      warnings: draw(_warnings),
    ),
  ),
  .element([Reproduced(_threw)]),
  _notThrown.map(NotReproduced.new),
]);
