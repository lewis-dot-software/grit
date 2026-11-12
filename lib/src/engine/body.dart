import 'dart:async';

import '../gen/gen.dart';

/// A property's body, which draws its inputs through [Draw] and fails by
/// throwing.
typedef Body = FutureOr<void> Function(Draw draw);
