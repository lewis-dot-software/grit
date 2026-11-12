import '../engine/body.dart';
import 'property_run.dart';
import 'settings.dart';

/// Searches [body] under [settings], the defaults where null, inside the
/// test that stands, such as a `testWidgets`, and fails it with the
/// outcome's report on every outcome but a pass.
///
/// The standing test's own timeout still bounds the search, so a test whose
/// search may run long is declared with `timeout: Timeout.none`.
Future<void> forAll(Body body, {Settings? settings}) =>
    PropertyRun.of(settings ?? .new(), callSite: .of(.current)).check(body);
