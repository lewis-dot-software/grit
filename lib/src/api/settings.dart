/// How one property is searched, each setting with a default no property has
/// to change.
final class Settings {
  /// The settings of a search, each defaulted where it is not given.
  ///
  /// [runs] is at least 1, and [shrinkSteps] never negative.
  Settings({
    int runs = 100,
    this.seed,
    int shrinkSteps = 5000,
    this.shrinkTime = const .new(seconds: 10),
  }) : runs = runs >= 1 ? runs : throw RangeError.range(runs, 1, null, 'runs'),
       shrinkSteps = RangeError.checkNotNegative(shrinkSteps, 'shrinkSteps');

  /// How many runs must return for the property to pass.
  final int runs;

  /// The seed the search's random choices are filled from, or null for a
  /// seed drawn afresh each search.
  ///
  /// One seed under the same other settings repeats one search, shrinking
  /// aside where its time runs out.
  final int? seed;

  /// The most candidates shrinking runs before it ends on the smallest
  /// failure found so far.
  final int shrinkSteps;

  /// The longest shrinking may take before it ends on the smallest failure
  /// found so far.
  ///
  /// The time bounds shrinking alone, so a property passes or fails alike
  /// however long its runs take.
  final Duration shrinkTime;
}
