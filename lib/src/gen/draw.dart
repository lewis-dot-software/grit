part of 'gen.dart';

/// What a property's body draws its inputs through, from one run's choices.
abstract final class Draw {
  Draw._(this._source);

  final ChoiceSource _source;
  final List<Drawn> _draws = [];
  final List<String> _notes = [];
  final List<Span> _spans = [];

  /// How many draws are in progress, so a draw inside a [Gen.build] body is
  /// told from one the property's body made, and each span sits at its
  /// depth.
  int _depth = 0;

  /// A value drawn from [gen], under [label] where the property's body names
  /// one.
  T call<T>(Gen<T> gen, {String? label}) {
    // The span is listed as the draw begins, so each span beneath it follows
    // it, and its width is set as it ends, whether it returns or throws.
    final int at = _spans.length;
    final int start = _source.length;
    _spans.add((start: start, width: 0, depth: _depth));
    _depth++;
    final T value;
    try {
      value = gen._body(this);
    } finally {
      _depth--;
      _spans[at] = (start: start, width: _source.length - start, depth: _depth);
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
