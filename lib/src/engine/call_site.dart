import 'failure.dart';
import 'frame.dart';

/// Where a search was called from, which says which frame of an error's stack
/// it was thrown from.
final class CallSite {
  CallSite._(this._package);

  /// The call site [stackTrace] was taken at: its first frame outside the
  /// Dart SDK, grit and every test package.
  ///
  /// A stack with no such frame names no package, and each failure is then
  /// read from its first frame outside those alone.
  factory CallSite.of(StackTrace stackTrace) =>
      ._(Frame.of(stackTrace).where(_isOwn).firstOrNull?.package);

  /// The packages a failure is never read from, besides the Dart SDK.
  static const Set<String> _ignored = {
    'package:grit',
    'package:checks',
    'package:flutter_test',
    'package:matcher',
    'package:stack_trace',
    'package:test',
    'package:test_api',
    'package:test_core',
  };

  /// The package of the call site's frame, or null where it had none.
  final String? _package;

  /// The failure of [error], thrown with [stackTrace].
  ///
  /// Its frame is the first of [stackTrace] in the call site's package, or
  /// where none is, the first outside the Dart SDK, grit and every test
  /// package.
  Failure failureOf(Object error, StackTrace stackTrace) {
    final List<Frame> own = Frame.of(stackTrace).where(_isOwn).toList();
    return (
      type: error.runtimeType,
      frame:
          own.where((Frame frame) => frame.package == _package).firstOrNull ??
          own.firstOrNull,
    );
  }

  static bool _isOwn(Frame frame) =>
      frame.package != 'dart' && !_ignored.contains(frame.package);
}
