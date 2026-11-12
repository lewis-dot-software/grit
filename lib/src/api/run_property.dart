import '../engine/outcome.dart';
import '../engine/search.dart';
import 'property_run.dart';
import 'settings.dart';

/// The outcome of searching [body] under [settings], the defaults where
/// null, with no test failed whatever it is.
Future<Outcome> runProperty(Body body, {Settings? settings}) => PropertyRun.of(
  settings ?? .new(),
  callSite: .of(StackTrace.current),
).outcome(body);
