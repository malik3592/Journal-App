import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:journal/core/errors.dart';

class SecurePinStore {
  SecurePinStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _hashKey = 'journal_pin_hash';
  static const _saltKey = 'journal_pin_salt';
  static const _bioKey = 'journal_biometrics_enabled';

  Future<bool> get hasPin async =>
      (await _storage.read(key: _hashKey))?.isNotEmpty == true;

  Future<({String hash, String salt})?> credentials() async {
    final hash = await _storage.read(key: _hashKey);
    final salt = await _storage.read(key: _saltKey);
    if (hash == null || salt == null || hash.isEmpty || salt.isEmpty)
      return null;
    return (hash: hash, salt: salt);
  }

  Future<void> savePin({required String hash, required String salt}) async {
    await _storage.write(key: _hashKey, value: hash);
    await _storage.write(key: _saltKey, value: salt);
  }

  Future<bool> get biometricsEnabled async =>
      (await _storage.read(key: _bioKey)) == 'true';

  Future<void> setBiometricsEnabled(bool enabled) async {
    if (!enabled) {
      await _storage.write(key: _bioKey, value: 'false');
      return;
    }
    if (!await hasPin) {
      throw AppException(
        'Set a PIN first. Biometrics cannot be turned on without a PIN.',
      );
    }
    await _storage.write(key: _bioKey, value: 'true');
  }
}
