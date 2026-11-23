import 'package:grit/grit.dart';
import 'package:grit/src/api/settings_source.dart';
import 'package:test/test.dart';

/// What a `Settings` source builds:
///
/// - `seed`: the seed it names.
/// - `settings`: the settings it builds, past its seed.
typedef _Read = ({int seed, Settings settings});

/// The seed and the settings that the Dart [source] builds, read back as
/// a consumer's analyser would read it.
_Read _read(String source) {
  final Map<String, String> named = {
    for (final String part
        in source.substring('Settings('.length, source.length - 1).split(', '))
      part.substring(0, part.indexOf(': ')): part.substring(
        part.indexOf(': ') + 2,
      ),
  };
  final Settings defaults = .new();
  return (
    seed: .parse(named['seed']!),
    settings: .new(
      runs: .parse(named['runs'] ?? '${defaults.runs}'),
      shrinkSteps: .parse(named['shrinkSteps'] ?? '${defaults.shrinkSteps}'),
      shrinkTime: switch (named['shrinkTime']) {
        null => defaults.shrinkTime,
        final String time => _readDuration(time),
      },
      expectedRunTime: switch (named['expectedRunTime']) {
        null => defaults.expectedRunTime,
        final String time => _readDuration(time),
      },
    ),
  );
}

/// The duration that the Dart [source], one `Duration` of a single unit,
/// builds.
Duration _readDuration(String source) {
  final RegExpMatch match = RegExp(r'^Duration\((\w+): (-?\d+)\)$')
      .firstMatch(source)!;
  final int count = .parse(match[2]!);
  return switch (match[1]) {
    'days' => .new(days: count),
    'hours' => .new(hours: count),
    'minutes' => .new(minutes: count),
    'seconds' => .new(seconds: count),
    'milliseconds' => .new(milliseconds: count),
    'microseconds' => .new(microseconds: count),
    final String? unit => throw StateError('no Duration unit $unit'),
  };
}

/// A time a whole number of one unit, so every unit is reached.
final Gen<Duration> _anyTime = .build(
  (Draw draw) => .new(
    microseconds:
        draw(.integer(min: 0, max: 1000)) *
        draw(
          .element([
            1,
            Duration.microsecondsPerMillisecond,
            Duration.microsecondsPerSecond,
            Duration.microsecondsPerMinute,
            Duration.microsecondsPerHour,
            Duration.microsecondsPerDay,
          ]),
        ),
  ),
);

void main() {
  group('the source of settings', () {
    test('at their defaults names the seed alone', () {
      expect(Settings().source(seed: 7), 'Settings(seed: 7)');
    });

    test('names the seed it is given over the seed the settings hold', () {
      expect(Settings(seed: 3).source(seed: 7), 'Settings(seed: 7)');
    });

    test('names each setting that is not its default', () {
      expect(
        Settings(
          runs: 1000,
          shrinkSteps: 3,
          shrinkTime: const .new(minutes: 2),
          expectedRunTime: const .new(seconds: 3),
        ).source(seed: 7),
        'Settings(seed: 7, runs: 1000, shrinkSteps: 3, '
        'shrinkTime: Duration(minutes: 2), '
        'expectedRunTime: Duration(seconds: 3))',
      );
    });

    test('RUN-3: A settings source built from a seed and settings reads '
        'back that seed and those settings.', () async {
      await forAll((Draw draw) {
        final int seed = draw(.integer(min: 0, max: 0xFFFFFFFF), label: 'seed');
        final Settings settings = .new(
          runs: draw(.integer(min: 1, max: 10000), label: 'runs'),
          shrinkSteps: draw(.integer(min: 0, max: 10000), label: 'shrinkSteps'),
          shrinkTime: draw(_anyTime, label: 'shrinkTime'),
          expectedRunTime: draw(_anyTime, label: 'expectedRunTime'),
        );
        final (seed: int readSeed, settings: Settings read) = _read(
          settings.source(seed: seed),
        );
        expect(readSeed, seed);
        expect(read.runs, settings.runs);
        expect(read.shrinkSteps, settings.shrinkSteps);
        expect(read.shrinkTime, settings.shrinkTime);
        expect(read.expectedRunTime, settings.expectedRunTime);
      });
    });

    test('builds a shrink time in the largest unit that holds it whole', () {
      String time(Duration shrinkTime) =>
          Settings(shrinkTime: shrinkTime).source(seed: 0);
      expect(time(const .new(days: 1)), contains('Duration(days: 1)'));
      expect(time(const .new(hours: 25)), contains('Duration(hours: 25)'));
      expect(time(const .new(seconds: 90)), contains('Duration(seconds: 90)'));
      expect(
        time(const .new(milliseconds: 1500)),
        contains('Duration(milliseconds: 1500)'),
      );
      expect(
        time(const .new(microseconds: 1001)),
        contains('Duration(microseconds: 1001)'),
      );
    });
  });
}
