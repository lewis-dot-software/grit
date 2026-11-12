import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/shrink/shrink.dart';

/// The state [shrink] ends in, told of each candidate whether [fails].
Shrunk shrunk(Shrink shrink, bool Function(ChoiceSequence) fails) {
  while (true) {
    switch (shrink) {
      case Shrunk():
        return shrink;
      case Shrinking():
        shrink = shrink.told(failed: fails(shrink.candidate));
    }
  }
}
