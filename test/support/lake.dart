import 'dart:io';

import 'package:test/test.dart';

/// Lake from elan at `$ELAN_HOME`, or at `~/.elan` where that is unset,
/// failing the test where neither `ELAN_HOME` nor `HOME` is set, and where
/// no lake stands there, naming the line that installs it.
File lake() {
  final Map<String, String> environment = Platform.environment;
  final String? elan =
      environment['ELAN_HOME'] ??
      switch (environment['HOME']) {
        final String home => '$home/.elan',
        null => null,
      };
  if (elan == null) {
    fail('no lake: neither ELAN_HOME nor HOME is set, so elan has no home');
  }
  final File lake = .new('$elan/bin/lake');
  if (!lake.existsSync()) {
    fail(
      'no lake at ${lake.path}: the Lean model needs elan, installed by '
      'curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --no-modify-path --default-toolchain none',
    );
  }
  return lake;
}
