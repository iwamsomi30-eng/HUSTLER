import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'db.dart';

/// Device PIN authentication.
/// New PINs use Argon2id with a unique random salt. Legacy SHA-256 PINs from
/// earlier stages are still accepted once and transparently upgraded.
class Auth {
  static final _argon2 = Argon2id(memory: 32 * 1024, iterations: 2, parallelism: 2, hashLength: 32);

  static Future<bool> hasPin() async => (await AppDb.instance.getSetting('pin_hash')) != null;

  static Future<void> setPin(String pin) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final key = await _argon2.deriveKeyFromPassword(password: pin, nonce: salt);
    await AppDb.instance.setSetting('pin_salt', base64UrlEncode(salt));
    await AppDb.instance.setSetting('pin_hash', base64UrlEncode(await key.extractBytes()));
    await AppDb.instance.setSetting('pin_scheme', 'argon2id-v1');
  }

  static String _legacyHash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<bool> verify(String pin) async {
    final saltRaw = await AppDb.instance.getSetting('pin_salt');
    final hashRaw = await AppDb.instance.getSetting('pin_hash');
    if (saltRaw == null || hashRaw == null) return false;
    final scheme = await AppDb.instance.getSetting('pin_scheme');
    if (scheme == 'argon2id-v1') {
      try {
        final salt = base64Url.decode(saltRaw);
        final key = await _argon2.deriveKeyFromPassword(password: pin, nonce: salt);
        final actual = base64UrlEncode(await key.extractBytes());
        return actual == hashRaw;
      } catch (_) { return false; }
    }
    final ok = _legacyHash(pin, saltRaw) == hashRaw;
    if (ok) await setPin(pin); // transparent security upgrade
    return ok;
  }
}
