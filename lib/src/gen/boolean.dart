part of 'gen.dart';

/// A boolean, one choice of 0 for false or 1 for true.
final Gen<bool> _boolean = ._(
  (Draw draw) => draw._source.choose(.binary).value == 1,
);
