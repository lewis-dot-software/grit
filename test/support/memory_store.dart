import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/store/loaded.dart';
import 'package:grit/src/store/store.dart';
import 'package:grit/src/store/store_key.dart';

/// A store that keeps what it holds in memory, and starts out holding
/// [held], the load each key gives.
final class MemoryStore implements Store {
  /// The store holding [held].
  MemoryStore([Map<StoreKey, Loaded> held = const {}]) : held = {...held};

  /// What each key holds, a key that holds nothing absent.
  final Map<StoreKey, Loaded> held;

  @override
  Loaded load(StoreKey key) => held[key] ?? Unstored();

  @override
  void save(StoreKey key, ChoiceSequence sequence) =>
      held[key] = Stored(sequence);

  @override
  void delete(StoreKey key) => held.remove(key);
}
