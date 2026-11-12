import '../choice/bound.dart';
import '../choice/choice_source.dart';
import '../choice/odds.dart';

part 'boolean.dart';
part 'draw.dart';
part 'element.dart';
part 'integer.dart';
part 'list.dart';

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
  /// from it is never simpler. [min] is never above [max], and the range
  /// holds no more values than a choice does, `1 << 63`.
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
    const int tries = 3;
    for (int i = 0; i < tries; i++) {
      final T value = draw(this);
      if (accepts(value)) return value;
    }
    draw._source.reject();
  });
}
