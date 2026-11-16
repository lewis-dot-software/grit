---
type: knowledge
aliases: property, forAll, runProperty, testWidgets, Flutter, declaring a property, body
---

# Properties

A property is declared one of three ways: `property` as a test of its own, `forAll` inside a test that already stands, and `runProperty` for its outcome as a value, with no test failed. Each takes a body and optional `Settings` ([settings.md](settings.md)).

A body is a `Body`, a function of a `Draw` that returns or completes, synchronous or `async` alike. It draws its inputs as it needs them ([drawing.md](drawing.md)), and fails by throwing, as `expect` does.

## A test of its own

`property` declares a test, inside `main` or a `group`, as `test` does:

```dart
property('reversing twice gives the list back', (draw) {
  final List<int> xs = draw(.list(.integer()), label: 'xs');
  expect(xs.reversed.toList().reversed.toList(), xs);
});
```

It takes the `settings` of its search, and `test`'s own `testOn`, `skip`, `tags`, `onPlatform` and `retry`. It takes no `timeout`, since the test is declared with none: no deadline of grit's fails a property, so it passes or fails alike on a loaded machine and an idle one.

Each attempt of a `retry` is a search of its own, with a seed of its own where the settings name none. A failed attempt stores its failure, so the next attempt replays it first ([replay.md](replay.md)), and a property that fails fails its retries too.

## Inside a test that stands

`forAll` searches inside a test already running, such as a `testWidgets`, or a `test` with setup of its own around the search:

```dart
test('a file reads back every string written to it', () async {
  final Directory directory = await Directory.systemTemp.createTemp();
  addTearDown(() => directory.delete(recursive: true));
  final File file = .new('${directory.path}/text');
  await forAll((draw) async {
    final String text = draw(.string(), label: 'text');
    await file.writeAsString(text);
    expect(await file.readAsString(), text);
  });
});
```

It fails the test it stands in on every outcome but a pass. That test's own timeout still bounds the search, `package:test`'s 30 seconds by default, so a test whose search may run long is declared with `timeout: Timeout.none`.

### Inside `testWidgets`

A Flutter package adds grit as a dev dependency beside `flutter_test`, which resolves with no more setup. A body is async where it awaits the tester:

```dart
testWidgets('a counter shows every count it is given', (tester) async {
  await forAll((draw) async {
    final int count = draw(.integer(min: 0, max: 1000), label: 'count');
    await tester.pumpWidget(Text('$count', textDirection: .ltr));
    expect(find.text('$count'), findsOneWidget);
  });
});
```

Every run shares the test's one `WidgetTester`, so each run pumps the widgets it checks rather than reading what the run before it left. `property` works in a Flutter package too, as a plain test beside the widget tests.

## The outcome as a value

`runProperty` searches as `property` does, and returns the outcome in place of failing a test:

```dart
final Outcome outcome = await runProperty((draw) {
  final int x = draw(.integer());
  if (x == 42) throw StateError('found it');
});
```

It suits a tool built on grit, or a test of a property's own outcome. The outcome is a sealed type that a `switch` reads case by case ([outcomes.md](outcomes.md)). It stores and replays its failure at its call site as the other two do.
