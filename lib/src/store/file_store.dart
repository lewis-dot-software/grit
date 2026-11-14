import 'dart:convert';
import 'dart:io';

import '../choice/choice_sequence.dart';
import '../choice/decoding.dart';
import '../choice/token.dart';
import 'loaded.dart';
import 'store.dart';
import 'store_key.dart';

/// A store of one file per key in a directory, each holding its sequence's
/// token and nothing else.
///
/// A file is named for a hash of its key, and written under a temporary name
/// then renamed, so no read, in this process or another, meets one half
/// written.
final class FileStore implements Store {
  /// The store in [directory], made where it is first written to.
  FileStore(this._directory);

  final Directory _directory;

  /// The FNV-1a hash's offset basis and prime, for 64 bits.
  static const int _offset = 0xcbf29ce484222325;
  static const int _prime = 0x100000001b3;

  @override
  Loaded load(StoreKey key) {
    final String text;
    try {
      // A token is ASCII, so any other byte decodes to a character no token
      // holds, and no file's bytes fail to decode.
      text = _file(key).readAsStringSync(encoding: latin1);
    } on PathNotFoundException {
      return Unstored();
    }
    return switch (Token.decode(text)) {
      Decoded(:final ChoiceSequence sequence) => Stored(sequence),
      final Undecodable reason => Unreadable(reason),
    };
  }

  @override
  void save(StoreKey key, ChoiceSequence sequence) {
    _directory.createSync(recursive: true);
    // A directory of its own, uniquely named, so two processes saving one key
    // at once never write one temporary file.
    final Directory temporary = _directory.createTempSync('.saving-');
    try {
      final File written = .new('${temporary.path}/token')
        ..writeAsStringSync(Token.encode(sequence), flush: true);
      written.renameSync(_file(key).path);
    } finally {
      temporary.deleteSync(recursive: true);
    }
  }

  @override
  void delete(StoreKey key) {
    try {
      _file(key).deleteSync();
    } on PathNotFoundException {
      // The key holds nothing already, which is all a delete asks.
    }
  }

  /// The file [key]'s sequence is kept in.
  File _file(StoreKey key) => .new('${_directory.path}/${_name(key)}');

  /// The 64-bit FNV-1a hash of [key]'s text, in 16 hex digits.
  static String _name(StoreKey key) {
    int hash = _offset;
    for (final int byte in utf8.encode(key.text)) {
      // Dart's integers wrap at 64 bits, as the hash's multiply does.
      hash = (hash ^ byte) * _prime;
    }
    return [
      hash >>> 32,
      hash & 0xFFFFFFFF,
    ].map((int half) => half.toRadixString(16).padLeft(8, '0')).join();
  }
}
