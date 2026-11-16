part of 'gen.dart';

/// What a property's body draws its inputs through, from one run's choices.
abstract final class Draw {
  Draw._(this._source);

  final ChoiceSource _source;
  final List<Drawn> _draws = [];
  final List<Span> _spans = [];
  final List<Thrown> _thrown = [];

  /// The last line noted, where one was, so a note is kept by one store of
  /// this field, which no error, a stack overflow among them, can leave
  /// half-written.
  _Note? _lastNote;

  /// Each error a callback of the property's own threw, by identity.
  final Set<Object> _theirsThrown = .identity();

  /// The writes to the draw's records, so a read of them after one was cut
  /// short throws the error that cut it.
  final Writes _writes = .new();

  /// How many draws are in progress, so a draw inside a [Gen.build] body is
  /// told from one the property's body made, and each span sits at its
  /// depth.
  int _depth = 0;

  /// The form the innermost draw in progress has named, where it has named
  /// one.
  ChoiceSequence? _form;

  /// A value drawn from [gen], under [label] where the property's body names
  /// one.
  T call<T>(Gen<T> gen, {String? label}) {
    try {
      return _drawn(gen, label);
    } on Object catch (error, stackTrace) {
      // An error is kept as it leaves the draw, since the body may catch it,
      // and once, since it leaves each draw around it as well.
      if (error is Error &&
          !_theirsThrown.contains(error) &&
          !identical(_thrown.lastOrNull?.error, error)) {
        _writes(() => _thrown.add((error: error, stackTrace: stackTrace)));
      }
      rethrow;
    }
  }

  /// The result of [callback], a callback of the property's own, an error
  /// it throws kept as its own whatever frame threw it, since a tear-off of
  /// the Dart SDK's has no frame of the property's.
  R _theirs<R>(R Function() callback) {
    try {
      return callback();
    } on Object catch (error) {
      _writes(() => _theirsThrown.add(error));
      rethrow;
    }
  }

  /// A value drawn from [gen], under [label], with its span and its draw
  /// kept.
  T _drawn<T>(Gen<T> gen, String? label) {
    // The span is listed as the draw begins, so each span beneath it follows
    // it, and its width is set as it ends, whether it returns or throws.
    final int at = _spans.length;
    final int start = _source.length;
    _writes(
      () => _spans.add((start: start, width: 0, depth: _depth, form: null)),
    );
    _depth++;
    final ChoiceSequence? around = _form;
    _form = null;
    final T value;
    try {
      value = gen._body(this);
    } finally {
      _depth--;
      final Span span = (
        start: start,
        width: _source.length - start,
        depth: _depth,
        form: _form,
      );
      _form = around;
      _writes(() => _spans[at] = span);
    }
    // The text is taken as the value is returned, since the body may sort,
    // clear or add to it in place before a report prints it.
    if (_depth == 0) {
      final Drawn drawn = (label: label, value: value, text: _textOf(value));
      _writes(() => _draws.add(drawn));
    }
    return value;
  }

  /// Names [form] as the choices of a simpler value to take the place of the
  /// innermost draw in progress.
  void _name(ChoiceSequence form) => _form = form;

  /// Rejects the run where [condition] is false.
  void assume(bool condition) {
    if (!condition) _source.reject();
  }

  /// Adds [line] to the report of the run, where it fails.
  void note(String line) => _lastNote = .new(line, _lastNote);
}
