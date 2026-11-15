part of 'gen.dart';

/// The draw of one run, which keeps what the property's body drew and noted.
///
/// A write to what it keeps that an error such as a stack overflow cut short
/// leaves it half-written, so from then on each of its lists throws that
/// error.
final class RunDraw extends Draw {
  /// The draw of one run, whose choices [source] hands over.
  RunDraw(super.source) : super._();

  /// The values the property's body drew, in order, with no value drawn
  /// inside a [Gen.build] body among them.
  List<Drawn> get draws => _read(_draws);

  /// The lines noted, in order.
  List<String> get notes {
    final List<String> lines = [];
    for (_Note? note = _lastNote; note != null; note = note.before) {
      lines.add(note.line);
    }
    return _read(lines.reversed);
  }

  /// The span of each draw made, the property's body's and those inside a
  /// [Gen.build] body alike, in the order the draws began.
  List<Span> get spans => _read(_spans);

  /// Each error thrown out of a draw, in the order thrown, but one a [Gen.map]
  /// or [Gen.filter] callback threw, and one thrown out of a draw inside
  /// another listed once.
  List<Thrown> get thrown => _read(_thrown);

  List<E> _read<E>(Iterable<E> kept) {
    _writes.throwIfCut();
    return .unmodifiable(kept);
  }
}
