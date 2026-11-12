import 'dart:io';

import 'package:test/test.dart';

/// Lake from elan at `$ELAN_HOME`, or at `~/.elan` where that is unset,
/// failing the test where none stands there and naming the line that
/// installs it.
File lake() {
  final String elan =
      Platform.environment['ELAN_HOME'] ??
      '${Platform.environment['HOME']}/.elan';
  final File lake = .new('$elan/bin/lake');
  if (!lake.existsSync()) {
    fail(
      'no lake at ${lake.path}: the Lean model needs elan, installed by '
      'curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --no-modify-path --default-toolchain none',
    );
  }
  return lake;
}
