import 'frame.dart';

/// The type of an error a run threw, and the frames it was thrown through.
final class Failure {
  /// The failure of an error of [type] thrown through [frames].
  Failure(this.type, this.frames);

  /// The type of the error thrown.
  final Type type;

  /// The frames of the error's stack a search reads, innermost first, from
  /// the one it was thrown from outward.
  final List<Frame> frames;

  /// The frame the error was thrown from, or null where its stack held none
  /// a search reads.
  Frame? get frame => frames.firstOrNull;

  /// Whether [other] is the same failure: an error of the same type thrown
  /// from the same frame, by library and line.
  ///
  /// A frame printed with no line was thrown from somewhere in its member,
  /// the code inlined into it among it, so it is the same frame as one
  /// whose frames run through that member, at whatever line.
  bool isAlike(Failure other) =>
      type == other.type &&
      switch ((frame, other.frame)) {
        (null, null) => true,
        (null, Frame()) || (Frame(), null) => false,
        (
          Frame(line: int()) && final Frame mine,
          Frame(line: int()) && final Frame theirs,
        ) =>
          mine.uri == theirs.uri && mine.line == theirs.line,
        (final Frame mine, final Frame theirs) =>
          (mine.line == null && other.frames.any(mine.runsAs)) ||
              (theirs.line == null && frames.any(theirs.runsAs)),
      };
}
