import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'db.dart';

/// PIN huhifadhiwa kwa njia salama (hashed + salt), haihifadhiwi wazi.
class Auth {
  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<bool> hasPin() async =>
      (await AppDb.instance.getSetting('pin_hash')) != null;

  static Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await AppDb.instance.setSetting('pin_salt', salt);
    await AppDb.instance.setSetting('pin_hash', _hash(pin, salt));
  }

  static Future<bool> verify(String pin) async {
    final salt = await AppDb.instance.getSetting('pin_salt');
    final hash = await AppDb.instance.getSetting('pin_hash');
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }
}
