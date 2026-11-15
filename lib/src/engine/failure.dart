import 'frame.dart';

/// The type of an error a run threw and the frame it was thrown from.
///
/// - `type`: the type of the error thrown.
/// - `frame`: the frame it was thrown from, or null where its stack held
///   none a search reads.
typedef Failure = ({Type type, Frame? frame});
