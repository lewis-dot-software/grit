import 'package:grit/grit.dart';
import 'package:test/test.dart';

/// The line of [fields], joined by commas, each comma and backslash inside a
/// field escaped by a backslash.
String encode(List<String> fields) => [
  for (final String field in fields)
    field.replaceAll(r'\', r'\\').replaceAll(',', r'\,'),
].join(',');

/// The fields of [line], as [encode] wrote them.
List<String> decode(String line) {
  final List<String> fields = [];
  final StringBuffer field = .new();
  for (int i = 0; i < line.length; i++) {
    switch (line[i]) {
      case r'\':
        field.write(line[++i]);
      case ',':
        fields.add('$field');
        field.clear();
      case final String character:
        field.write(character);
    }
  }
  return fields..add('$field');
}

/// A row whose fields lean towards the characters [encode] escapes, so a
/// search meets them often.
final Gen<List<String>> row = .list(
  .oneOf([.string(alphabet: .of(r'a,\')), .string()]),
  minLength: 1,
);

/// Properties of a row encoder: `dart test example/example.dart` runs them.
void main() {
  property('decoding an encoded row gives the row back', (draw) {
    final List<String> fields = draw(row, label: 'row');
    final String line = encode(fields);
    draw.note('encoded as $line');
    expect(decode(line), fields);
  });

  property('a row with nothing to escape encodes as its fields joined', (draw) {
    final List<String> fields = draw(
      .list(.string(alphabet: .lettersAndDigits)),
      label: 'row',
    );
    expect(encode(fields), fields.join(','));
  });

  test(
    'a row of the same field holds one comma fewer than its fields',
    () async {
      await forAll((draw) {
        final String field = draw(.string(alphabet: .lettersAndDigits));
        final int count = draw(.integer(min: 1, max: 20), label: 'count');
        final String line = encode(.filled(count, field));
        expect(','.allMatches(line).length, count - 1);
      });
    },
  );
}
