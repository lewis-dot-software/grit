part of 'gen.dart';

/// One value a property's body drew.
///
/// - `label`: the label the body drew it under, or null where it named none.
/// - `value`: the value the draw returned, which the body may since have
///   changed in place.
/// - `text`: the value's text as the draw returned it.
typedef Drawn = ({String? label, Object? value, String text});

/// What a property's body draws its inputs through, from one run's choices.
final class Draw {
  /// The draw of one run, whose choices [source] hands over.
  Draw(this._source);

  final ChoiceSource _source;
  final List<Drawn> _draws = [];
  final List<String> _notes = [];

  /// How many draws are in progress, so a draw inside a [Gen.build] body is
  /// told from one the property's body made.
  int _depth = 0;

  /// The values the property's body drew, in order, with no value drawn
  /// inside a [Gen.build] body among them.
  List<Drawn> get draws => .unmodifiable(_draws);

  /// The lines noted, in order.
  List<String> get notes => .unmodifiable(_notes);

  /// A value drawn from [gen], under [label] where the property's body names
  /// one.
  T call<T>(Gen<T> gen, {String? label}) {
    _depth++;
    final T value;
    try {
      value = gen._body(this);
    } finally {
      _depth--;
    }
    // The text is taken as the value is returned, since the body may sort,
    // clear or add to it in place before a report prints it.
    if (_depth == 0) _draws.add((label: label, value: value, text: '$value'));
    return value;
  }

  /// Rejects the run where [condition] is false.
  void assume(bool condition) {
    if (!condition) _source.reject();
  }

  /// Adds [line] to the report of the run, where it fails.
  void note(String line) => _notes.add(line);
}
