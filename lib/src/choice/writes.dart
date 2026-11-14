/// The writes to one run's records, and the error that cut one short.
///
/// An error such as a stack overflow can strike part way through a write,
/// leaving the records as they stood then, such as a list with a slot and no
/// value in it. Once a write is cut short, [throwIfCut] throws the error that
/// cut it, so no record is read half-written.
final class Writes {
  _Cut? _cut;

  /// Makes [change], a write to the records, keeping the error that cuts it
  /// short.
  void call(void Function() change) {
    try {
      change();
    } on Object catch (error, stackTrace) {
      // A catch of any object tests no type, and keeping the error calls
      // nothing, so a stack that ran out inside the write cannot run out
      // again before the error is kept.
      _cut ??= (error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Throws the error that cut a write short, where one did.
  void throwIfCut() {
    if (_cut case (:final Object error, :final StackTrace stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

/// The error that cut a write short.
///
/// - `error`: the error thrown.
/// - `stackTrace`: the stack it was thrown with.
typedef _Cut = ({Object error, StackTrace stackTrace});
