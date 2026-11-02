import 'dart:convert';
import 'dart:math';
import '../core/db.dart';

/// Device identity used by secure cloud synchronization.
/// This service intentionally contains no file-transfer sync logic.
class SyncService {
  static Future<String> deviceId() async {
    final db = AppDb.instance;
    var id = await db.getSetting('sync_device_id');
    if (id == null || id.length < 16) {
      final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      id = base64UrlEncode(bytes).replaceAll('=', '');
      await db.setSetting('sync_device_id', id);
    }
    return id;
  }
}
