import 'package:meta/meta.dart';
import 'package:test/test.dart';

import '../engine/call_site.dart';
import '../engine/body.dart';
import 'property_run.dart';
import 'settings.dart';

/// Declares a test of [description] that searches [body] under [settings],
/// the defaults where null, and fails with the outcome's report on every
/// outcome but a pass.
///
/// [testOn], [skip], [tags], [onPlatform] and [retry] are `test`'s own. The
/// test is declared with no timeout, since no deadline fails a property.
/// Each search of a retry draws a seed of its own where [settings] names
/// none.
@isTest
void property(
  Object? description,
  Body body, {
  Settings? settings,
  String? testOn,
  Object? skip,
  Object? tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) {
  // The stack is read here, at the declaration, since the test's own body
  // runs with no frame of the consumer's beneath it.
  final CallSite callSite = .of(.current);
  test(
    description,
    () => PropertyRun.of(settings ?? .new(), callSite: callSite).check(body),
    testOn: testOn,
    timeout: .none,
    skip: skip,
    tags: tags,
    onPlatform: onPlatform,
    retry: retry,
  );
}
