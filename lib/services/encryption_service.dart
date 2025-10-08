import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureKeyStorage {
  const SecureKeyStorage();

  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});
}

class FlutterSecureKeyStorage implements SecureKeyStorage {
  const FlutterSecureKeyStorage();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}

@visibleForTesting
class InMemorySecureKeyStorage implements SecureKeyStorage {
  InMemorySecureKeyStorage();

  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }
}

class EncryptionService {
  EncryptionService._({SecureKeyStorage? storage})
      : _storage = storage ?? const FlutterSecureKeyStorage();

  factory EncryptionService.withStorage(SecureKeyStorage storage) =>
      EncryptionService._(storage: storage);

  static EncryptionService instance = EncryptionService._();

  final SecureKeyStorage _storage;
  final Random _random = _createSecureRandom();

  static const String _storageKey = 'contact_db_master_key';
  static const String encryptedPrefix = 'enc:';
  static const String _separator = ':';

  Key? _key;
  Encrypter? _encrypter;

  static Random _createSecureRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  Future<void> ensureInitialized() async {
    if (_encrypter != null && _key != null) return;

    var storedKey = await _storage.read(key: _storageKey);
    if (storedKey == null || storedKey.isEmpty) {
      final keyBytes = Uint8List.fromList(
        List<int>.generate(32, (_) => _random.nextInt(256)),
      );
      storedKey = base64Encode(keyBytes);
      await _storage.write(key: _storageKey, value: storedKey);
    }

    _key = Key.fromBase64(storedKey);
    _encrypter = Encrypter(AES(_key!, mode: AESMode.cbc));
  }

  bool isEncrypted(String value) => value.startsWith(encryptedPrefix);

  String ensureEncrypted(String value) {
    if (value.isEmpty) return value;
    return isEncrypted(value) ? value : encrypt(value);
  }

  String ensureDecrypted(String value) {
    if (value.isEmpty) return value;
    return isEncrypted(value) ? decrypt(value) : value;
  }

  String encrypt(String value) {
    if (value.isEmpty) return value;
    final encrypter = _encrypter;
    if (encrypter == null) {
      throw StateError('EncryptionService has not been initialized');
    }

    final ivBytes = Uint8List.fromList(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final iv = IV(ivBytes);
    final encrypted = encrypter.encrypt(value, iv: iv);
    final payload = '${base64Encode(iv.bytes)}$_separator${encrypted.base64}';
    return '$encryptedPrefix$payload';
  }

  String decrypt(String value) {
    if (value.isEmpty) return value;
    if (!isEncrypted(value)) return value;
    final encrypter = _encrypter;
    if (encrypter == null) {
      throw StateError('EncryptionService has not been initialized');
    }

    final payload = value.substring(encryptedPrefix.length);
    final parts = payload.split(_separator);
    if (parts.length != 2) return value;

    final iv = IV(base64Decode(parts[0]));
    final encrypted = Encrypted.fromBase64(parts[1]);
    return encrypter.decrypt(encrypted, iv: iv);
  }

  String hash(String value) {
    final digest = sha256.convert(utf8.encode(value));
    return digest.toString();
  }

  @visibleForTesting
  static void resetForTests([EncryptionService? service]) {
    instance = service ?? EncryptionService._();
  }
}
