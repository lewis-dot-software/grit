import '../engine/search.dart';
import 'property_run.dart';
import 'settings.dart';

/// Searches [body] under [settings], the defaults where null, inside the
/// test that stands, such as a `testWidgets`, and fails it on every outcome
/// but a pass.
///
/// The failure's message reports the outcome: a failed property's smallest
/// failing case, a flaky one's failure and its replay, or how many runs a
/// property that gave up saw rejected and overrun.
///
/// The standing test's own timeout still bounds the search, so a test whose
/// search may run long is declared with `timeout: Timeout.none`.
Future<void> forAll(Body body, {Settings? settings}) => PropertyRun.of(
  settings ?? .new(),
  callSite: .of(StackTrace.current),
).check(body);
