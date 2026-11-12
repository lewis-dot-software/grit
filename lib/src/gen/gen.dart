import '../choice/bound.dart';
import '../choice/choice.dart';
import '../choice/choice_source.dart';
import '../choice/odds.dart';

part 'alphabet.dart';
part 'boolean.dart';
part 'collection.dart';
part 'draw.dart';
part 'drawn.dart';
part 'element.dart';
part 'integer.dart';
part 'list.dart';
part 'one_of.dart';
part 'run_draw.dart';
part 'set.dart';
part 'string.dart';

/// How many draws a generator makes towards one value it accepts before it
/// gives up.
const int _tries = 3;

/// A generator: a value drawn from a run's choices, which shrinks as its
/// choices do.
///
/// Its static members are the generators, named by dot shorthand wherever a
/// [Gen] is expected.
final class Gen<T> {
  Gen._(this._body);

  final T Function(Draw draw) _body;

  /// The generator whose value is [body]'s, drawn from the generators it
  /// calls [draw] on, in order.
  ///
  /// Its simplest value is [body]'s on the simplest value of each generator
  /// it draws.
  static Gen<T> build<T>(T Function(Draw draw) body) => ._(body);

  /// An integer from [min] to [max], each inclusive, by default those of a
  /// 32-bit signed integer.
  ///
  /// Its simplest value is the one in range nearest 0, and a value further
  /// from it is never simpler. [min] is never above [max], and [max] is at
  /// most [Choice.largest] above [min].
  static Gen<int> integer({int min = -0x80000000, int max = 0x7FFFFFFF}) =>
      _integer(min: min, max: max);

  /// A boolean, whose simplest value is false.
  static Gen<bool> boolean() => _boolean;

  /// A list of [element]'s values, from [minLength] long to [maxLength], each
  /// inclusive, with no maximum where [maxLength] is null.
  ///
  /// Its simplest value is [minLength] of [element]'s simplest values.
  /// [minLength] is never negative, nor above [maxLength].
  static Gen<List<E>> list<E>(
    Gen<E> element, {
    int minLength = 0,
    int? maxLength,
  }) => _list(element, minLength: minLength, maxLength: maxLength);

  /// One of [values], which holds at least one.
  ///
  /// Its simplest value is the first, and each value is simpler than the
  /// ones after it. Later changes to [values] change nothing it draws.
  static Gen<T> element<T>(Iterable<T> values) => _element(values);

  /// A string of [alphabet]'s characters, from [minLength] code points long
  /// to [maxLength], each inclusive, with no maximum where [maxLength] is
  /// null.
  ///
  /// Its lengths count code points, never UTF-16 code units. Its simplest
  /// value is [minLength] of [alphabet]'s simplest character. [minLength] is
  /// never negative, nor above [maxLength].
  static Gen<String> string({
    Alphabet alphabet = .unicode,
    int minLength = 0,
    int? maxLength,
  }) => _string(alphabet, minLength: minLength, maxLength: maxLength);

  /// A value of one of [generators], which holds at least one, the generator
  /// chosen before its value is drawn.
  ///
  /// Its simplest value is the first generator's simplest, and each
  /// generator is simpler than the ones after it. Later changes to
  /// [generators] change nothing it draws.
  static Gen<T> oneOf<T>(Iterable<Gen<T>> generators) => _oneOf(generators);

  /// A set of [element]'s values, from [minSize] elements to [maxSize], each
  /// inclusive, with no maximum where [maxSize] is null.
  ///
  /// A draw that repeats an element the set holds, by `==`, is drawn again,
  /// up to three draws in all. Once those are spent the set ends where it
  /// stands, and rejects the run where it holds fewer than [minSize].
  ///
  /// Its simplest value is the empty set where [minSize] is 0, and a set of
  /// [element]'s simplest value where it is 1. All-zero choices reject the
  /// run where [minSize] is 2 or more, since each further draw repeats that
  /// value. [minSize] is never negative, nor above [maxSize].
  static Gen<Set<E>> set<E>(Gen<E> element, {int minSize = 0, int? maxSize}) =>
      _set(element, minSize: minSize, maxSize: maxSize);

  /// The generator of [convert] applied to this one's values.
  ///
  /// Its simplest value is [convert] applied to this one's.
  Gen<R> map<R>(R Function(T value) convert) =>
      ._((Draw draw) => convert(draw(this)));

  /// The generator of this one's values that [accepts] holds for.
  ///
  /// It draws up to three times, keeping the first value [accepts] holds
  /// for, and rejects the run where it holds for none. Its simplest value is
  /// this one's, where [accepts] holds for it.
  Gen<T> filter(bool Function(T value) accepts) => ._((Draw draw) {
    for (int i = 0; i < _tries; i++) {
      final T value = draw(this);
      if (accepts(value)) return value;
    }
    draw._source.reject();
  });
}
