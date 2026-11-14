part of 'gen.dart';

/// The draw of one run, which keeps what the property's body drew and noted.
final class RunDraw extends Draw {
  /// The draw of one run, whose choices [source] hands over.
  RunDraw(super.source) : super._();

  /// The values the property's body drew, in order, with no value drawn
  /// inside a [Gen.build] body among them.
  List<Drawn> get draws => .unmodifiable(_draws);

  /// The lines noted, in order.
  List<String> get notes => .unmodifiable(_notes);

  /// The span of each draw made, the property's body's and those inside a
  /// [Gen.build] body alike, in the order the draws began.
  List<Span> get spans => .unmodifiable(_spans);

  /// Each error thrown out of a draw, in the order thrown, but one a [Gen.map]
  /// or [Gen.filter] callback threw, and one thrown out of a draw inside
  /// another listed once.
  List<Thrown> get thrown => .unmodifiable(_thrown);
}
