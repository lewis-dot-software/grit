import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// A binary heap: a head no greater than any key beneath it, over two
/// heaps, each null where it is empty.
final class _Heap {
  _Heap(this.head, this.left, this.right);

  final int head;
  final _Heap? left;
  final _Heap? right;

  @override
  bool operator ==(Object other) =>
      other is _Heap &&
      other.head == head &&
      other.left == left &&
      other.right == right;

  @override
  int get hashCode => Object.hash(head, left, right);

  @override
  String toString() => '($head, ${left ?? 'None'}, ${right ?? 'None'})';
}

/// The keys of [heap], depth first, each node's right before its left.
List<int> _keys(_Heap? heap) {
  final List<int> keys = [];
  final List<_Heap?> stack = [heap];
  while (stack.isNotEmpty) {
    if (stack.removeLast() case final _Heap node) {
      keys.add(node.head);
      stack
        ..add(node.left)
        ..add(node.right);
    }
  }
  return keys;
}

/// The heap of [first]'s keys and [second]'s.
_Heap? _merged(_Heap? first, _Heap? second) => switch ((first, second)) {
  (null, _) => second,
  (_, null) => first,
  (final _Heap a, final _Heap b) when a.head <= b.head => _Heap(
    a.head,
    _merged(a.right, b),
    a.left,
  ),
  (final _Heap a, final _Heap b) => _Heap(b.head, _merged(b.right, a), b.left),
};

/// The keys of [heap] as a wrong sort reads them: the head, then the keys of
/// its two heaps merged, in [_keys]'s order and not sorted.
List<int> _wronglySorted(_Heap? heap) => switch (heap) {
  null => [],
  final _Heap node => [node.head, ..._keys(_merged(node.left, node.right))],
};

/// A heap whose keys are each at least [least], empty three times in four,
/// as the challenge's source draws it, so a heap is finite.
Gen<_Heap?> _heap(int least) => .build((Draw draw) {
  if (draw(.integer(min: 0, max: 3)) < 3) return null;
  final int head = draw(.integer(min: least));
  return _Heap(head, draw(_heap(head)), draw(_heap(head)));
});

/// The seeds this challenge's shrinking is held to: those whose search
/// shrinks to the smallest known.
///
/// Seeds 1, 2, 4, 7 and 8 stop at the smallest's mirror, whose subtrees
/// would need swapping, and 3, 6 and 9 at a heap that needs its subtrees
/// swapped or a node lifted past its parent.
const List<int> _seeds = [0, 5];

/// A binary heap, under the false property that a wrong sort of its keys is
/// sorted and holds its keys.
void main() {
  challenge(
    'binheap',
    (Draw draw) {
      final _Heap? heap = draw(_heap(0));
      final List<int> sorted = _wronglySorted(heap);
      expect(sorted, [...sorted]..sort());
      expect(sorted, [..._keys(heap)]..sort());
    },
    [_Heap(0, null, _Heap(0, _Heap(0, null, null), _Heap(1, null, null)))],
    shrinks: _seeds,
  );
}
