import 'dart:io';
import 'dart:isolate';

import 'package:grit/grit.dart';
import 'package:grit/src/store/file_store.dart';
import 'package:grit/src/store/loaded.dart';
import 'package:grit/src/store/store.dart';
import 'package:grit/src/store/store_key.dart';
import 'package:test/test.dart';

import '../support/inputs.dart';
import '../support/small.dart';

/// A directory of its own for one test, deleted once the test ends.
Directory _directory() {
  final Directory directory = .systemTemp.createTempSync('grit-');
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory;
}

/// The sequence [loaded] holds, or null where it holds none.
ChoiceSequence? _sequenceOf(Loaded loaded) => switch (loaded) {
  Stored(:final ChoiceSequence sequence) => sequence,
  Unstored() || Unreadable() => null,
};

/// Keys that differ by a frame, a line, their order and a character alone.
final List<StoreKey> _keys = [
  const .new(''),
  const .new('file:///a_test.dart:7'),
  const .new('file:///a_test.dart:8'),
  const .new('file:///b_test.dart:7'),
  const .new('file:///a_test.dart:7\nfile:///a_test.dart:20'),
  const .new('file:///a_test.dart:20\nfile:///a_test.dart:7'),
  const .new('file:///ä_test.dart:7'),
];

/// Each file and directory [directory] holds, at any depth, by its path from
/// [directory].
Set<String> _files(Directory directory) => {
  for (final FileSystemEntity entity in directory.listSync(recursive: true))
    entity.path.substring(directory.path.length + 1),
};

void main() {
  group('a file store', () {
    test('holds nothing under a key it never saved, and makes no file', () {
      final Directory directory = _directory();
      final Directory store = .new('${directory.path}/grit');
      expect(FileStore(store).load(_keys[1]), isA<Unstored>());
      expect(store.existsSync(), isFalse);
    });

    test('loads what it saved, making its directory', () {
      final Directory directory = .new('${_directory().path}/a/grit');
      final FileStore store = .new(directory);
      store.save(_keys[1], sequenceOf([3, 0, 40]));
      expect(_sequenceOf(store.load(_keys[1])), sequenceOf([3, 0, 40]));
    });

    test('keeps a key\'s sequence in one file holding its token alone, and '
        'nothing else in its directory', () {
      final Directory directory = _directory();
      FileStore(directory).save(_keys[1], sequenceOf([3, 0, 40]));
      final List<FileSystemEntity> entities = directory.listSync();
      expect(entities, hasLength(1));
      expect((entities.single as File).readAsStringSync(), 'grit1:3.0.14');
    });

    test('keeps the last sequence saved under a key', () {
      final FileStore store = .new(_directory());
      store.save(_keys[1], sequenceOf([3]));
      store.save(_keys[1], sequenceOf([1, 2]));
      expect(_sequenceOf(store.load(_keys[1])), sequenceOf([1, 2]));
    });

    test('holds nothing under a key once deleted, nor any file', () {
      final Directory directory = _directory();
      final FileStore store = .new(directory);
      store.save(_keys[1], sequenceOf([3]));
      store.delete(_keys[1]);
      expect(store.load(_keys[1]), isA<Unstored>());
      expect(directory.listSync(), isEmpty);
    });

    test('deletes a key that holds nothing, with nothing thrown', () {
      final Directory directory = _directory();
      FileStore(directory).delete(_keys[1]);
      FileStore(.new('${directory.path}/absent')).delete(_keys[1]);
    });

    test('loads a file that is no token, or a token of another format, as '
        'unreadable, saying which', () {
      final Directory directory = _directory();
      final FileStore store = .new(directory);
      store.save(_keys[1], sequenceOf([3]));
      final File file = directory.listSync().single as File;
      file.writeAsStringSync('grit1:03');
      expect(
        store.load(_keys[1]),
        isA<Unreadable>().having(
          (Unreadable unreadable) => unreadable.reason,
          'reason',
          isA<NotAToken>(),
        ),
      );
      file.writeAsStringSync('grit2:3');
      expect(
        store.load(_keys[1]),
        isA<Unreadable>().having(
          (Unreadable unreadable) => unreadable.reason,
          'reason',
          isA<OtherFormat>().having(
            (OtherFormat other) => other.format,
            'format',
            'grit2',
          ),
        ),
      );
    });

    test('loads a file whose bytes are not text as unreadable, no token', () {
      final Directory directory = _directory();
      final FileStore store = .new(directory);
      store.save(_keys[1], sequenceOf([3]));
      (directory.listSync().single as File).writeAsBytesSync([0xff, 0xfe, 0]);
      expect(
        store.load(_keys[1]),
        isA<Unreadable>().having(
          (Unreadable unreadable) => unreadable.reason,
          'reason',
          isA<NotAToken>(),
        ),
      );
    });

    test('names a key\'s file the same in each store over one directory', () {
      final Directory directory = _directory();
      FileStore(directory).save(_keys[4], sequenceOf([2]));
      expect(_sequenceOf(FileStore(directory).load(_keys[4])), sequenceOf([2]));
    });

    test('saves under one key from many stores at once, leaving one file that '
        'holds one of their sequences', () async {
      final Directory directory = _directory();
      final List<ChoiceSequence> sequences = [
        for (int i = 0; i < 20; i++) sequenceOf([i, i]),
      ];
      // Each save runs in an isolate of its own, so the saves interleave as
      // two test files' do.
      await Future.wait([
        for (final ChoiceSequence sequence in sequences)
          Isolate.run(() => FileStore(directory).save(_keys[1], sequence)),
      ]);
      expect(_files(directory), hasLength(1));
      expect(
        sequences,
        contains(_sequenceOf(FileStore(directory).load(_keys[1]))),
      );
    });
  });

  group('over every small sequence', () {
    test('REP-5: A sequence saved under a key loads under that key '
        'until it is deleted, and under no other.', () {
      final Store store = FileStore(_directory());
      for (final ChoiceSequence sequence in everySequence(
        length: 3,
        bound: 3,
      )) {
        for (final StoreKey key in _keys) {
          store.save(key, sequence);
          for (final StoreKey other in _keys) {
            expect(
              _sequenceOf(store.load(other)),
              other == key ? sequence : null,
              reason: '$sequence under $key, loaded under $other',
            );
          }
          store.delete(key);
          expect(store.load(key), isA<Unstored>(), reason: '$sequence');
        }
      }
    });
  });

  group('on grit, over larger inputs', () {
    // Made once the group's test is to run, so a run that leaves it out
    // leaves no directory behind.
    late final Directory directory;
    late final Store store;
    setUpAll(() {
      directory = .systemTemp.createTempSync('grit-');
      store = FileStore(directory);
    });
    tearDownAll(() => directory.deleteSync(recursive: true));
    final Gen<StoreKey> anyKey = .string().map(StoreKey.new);

    property('REP-5: A sequence saved under a key loads under that key '
        'until it is deleted, and under no other.', (Draw draw) {
      final StoreKey key = draw(anyKey, label: 'key');
      final StoreKey other = draw(anyKey, label: 'other');
      final ChoiceSequence sequence = draw(anySequence, label: 'sequence');
      store.save(key, sequence);
      try {
        expect(_sequenceOf(store.load(key)), sequence);
        if (other != key) expect(store.load(other), isA<Unstored>());
        store.delete(key);
        expect(store.load(key), isA<Unstored>());
      } finally {
        store.delete(key);
      }
    });
  });
}
