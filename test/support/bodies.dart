import 'package:grit/src/engine/body.dart';
import 'package:grit/src/gen/gen.dart';

/// A body that fails on its first run alone.
Body failsOnce() {
  bool failed = false;
  return (Draw draw) {
    if (failed) return;
    failed = true;
    throw StateError('once');
  };
}

/// A body that fails wherever it draws true.
void failsOnTrue(Draw draw) {
  if (draw(.boolean())) throw StateError('true');
}
