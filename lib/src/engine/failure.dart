import 'frame.dart';

/// What makes two failures the same, equal where both fields are.
///
/// - `type`: the type of the error thrown.
/// - `frame`: the frame it was thrown from, or null where its stack held
///   none a search reads.
typedef Failure = ({Type type, Frame? frame});
