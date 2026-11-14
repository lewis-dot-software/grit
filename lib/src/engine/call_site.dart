import '../store/store_key.dart';
import 'failure.dart';
import 'frame.dart';

/// Where a search was called from, which says which frame of an error's stack
/// it was thrown from.
final class CallSite {
  CallSite._(this._package, this.key);

  /// The call site [stackTrace] was taken at: its first frame outside the
  /// Dart SDK, grit and every test package.
  ///
  /// A stack with no such frame names no package, and each failure is then
  /// read from its first frame outside those alone.
  factory CallSite.of(StackTrace stackTrace) {
    final List<Frame> own = Frame.of(stackTrace).where(_isOwn).toList();
    final String? package = own.firstOrNull?.package;
    return ._(
      package,
      .new(
        [
          for (final Frame frame in own)
            if (frame.package == package) '$frame',
        ].join('\n'),
      ),
    );
  }

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

  /// What the call site's failure is stored under: every frame of its stack
  /// in its package, by library and line, so a call behind a helper is
  /// keyed by where the helper is called.
  ///
  /// A stack with no frame outside the Dart SDK, grit and every test package
  /// is keyed by no frame.
  final StoreKey key;

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
