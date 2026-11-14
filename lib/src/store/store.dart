import '../choice/choice_sequence.dart';
import 'loaded.dart';
import 'store_key.dart';

/// Where each call site's smallest failing sequence is kept between
/// searches, one under each key.
///
/// Every member is synchronous, since asynchronous file I/O can deadlock
/// inside a `testWidgets`.
abstract interface class Store {
  /// What [key] holds.
  Loaded load(StoreKey key);

  /// Keeps [sequence] under [key], in place of anything it held.
  void save(StoreKey key, ChoiceSequence sequence);

  /// Keeps nothing under [key].
  void delete(StoreKey key);
}
