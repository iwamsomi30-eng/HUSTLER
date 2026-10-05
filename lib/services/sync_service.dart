import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/db.dart';

class SyncResult {
  final int imported;
  final int skipped;
  final int conflicts;
  const SyncResult({required this.imported, required this.skipped, required this.conflicts});
}

/// STEP 9 transport layer. It deliberately separates pairing/transport from the
/// database so a hosted cloud transport can be added without changing the UI.
class SyncService {
  static const _format = 'MFUKO_SYNC_V1';
  static String _randomCode() => (100000 + Random.secure().nextInt(900000)).toString();

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

  static Future<String> newPairingCode() async {
    final code = _randomCode();
    await AppDb.instance.setSetting('sync_pairing_code', code);
    await AppDb.instance.setSetting('sync_pairing_expires', DateTime.now().add(const Duration(minutes: 5)).toIso8601String());
    return code;
  }

  static Future<String?> pairingCode() => AppDb.instance.getSetting('sync_pairing_code');

  static Future<bool> pairingCodeValid(String code) async {
    final saved = await pairingCode();
    final exp = await AppDb.instance.getSetting('sync_pairing_expires');
    return saved == code && exp != null && DateTime.tryParse(exp)?.isAfter(DateTime.now()) == true;
  }

  static Future<String> createPackage(String code) async {
    if (!await pairingCodeValid(code)) throw StateError('PAIRING_CODE_INVALID');
    final db = AppDb.instance.db;
    final tables = <String>['settings','contribution_batches','fungu_contributions','other_contributions','expenditure_batches','expenditure_entries'];
    final data = <String, dynamic>{};
    for (final table in tables) data[table] = await db.query(table);
    final payload = jsonEncode({'format': _format, 'created_at': DateTime.now().toIso8601String(), 'device_id': await deviceId(), 'data': data});
    final key = sha256.convert(utf8.encode(code)).bytes;
    final bytes = utf8.encode(payload);
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(bytes, secretKey: SecretKey(key));
    final envelope = jsonEncode({'format': _format, 'cipher': base64Encode(secretBox.concatenation()), 'checksum': sha256.convert(bytes).toString()});
    return envelope;
  }

  static Future<String> exportPackageToFile(String code) async {
    final envelope = await createPackage(code);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/MFUKO_SYNC_${DateTime.now().millisecondsSinceEpoch}.mfuko';
    // ignore: avoid_dynamic_calls
    await _write(path, envelope);
    return path;
  }

  static Future<void> sharePackage(String path) async {
    await Share.shareXFiles([XFile(path)], text: 'MFUKO WA MAPATO YA KANISA — Sync Package');
  }

  static Future<SyncResult> importPackage({required String code}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (result == null) throw StateError('IMPORT_CANCELLED');
    final file = result.files.single;
    final raw = file.bytes != null ? utf8.decode(file.bytes!) : await _read(file.path!);
    return _mergeEnvelope(raw, code);
  }

  static Future<SyncResult> _mergeEnvelope(String raw, String code) async {
    final env = jsonDecode(raw) as Map<String,dynamic>;
    if (env['format'] != _format) throw StateError('SYNC_FORMAT_UNSUPPORTED');
    final encrypted = base64Decode(env['cipher'] as String);
    final key = sha256.convert(utf8.encode(code)).bytes;
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox.fromConcatenation(encrypted, nonceLength: algorithm.nonceLength, macLength: algorithm.macAlgorithm.macLength);
    List<int> plain;
    try {
      plain = await algorithm.decrypt(secretBox, secretKey: SecretKey(key));
    } catch (_) {
      throw StateError('SYNC_CODE_OR_FILE_INVALID');
    }
    final checksum = sha256.convert(plain).toString();
    if (checksum != env['checksum']) throw StateError('SYNC_CODE_OR_FILE_INVALID');
    final pkg = jsonDecode(utf8.decode(plain)) as Map<String,dynamic>;
    if (pkg['format'] != _format) throw StateError('SYNC_FORMAT_UNSUPPORTED');
    final data = Map<String,dynamic>.from(pkg['data'] as Map);
    final db = AppDb.instance.db;
    int imported = 0, skipped = 0, conflicts = 0;
    await db.transaction((txn) async {
      // Settings: only fill missing keys; the local device remains authoritative for existing settings.
      for (final row in (data['settings'] as List).cast<Map>()) {
        final keyName = '${row['key']}';
        final exists = await txn.query('settings', where: 'key=?', whereArgs: [keyName], limit: 1);
        if (exists.isEmpty) { await txn.insert('settings', {'key': keyName, 'value': row['value']}); imported++; } else { skipped++; }
      }
      // Parent batches first; duplicates are detected using their business identity.
      final batchMap = <int,int>{};
      for (final table in ['contribution_batches','expenditure_batches']) {
        for (final rawRow in (data[table] as List).cast<Map>()) {
          final r = Map<String,dynamic>.from(rawRow);
          r.remove('id');
          final existing = table == 'contribution_batches'
              ? await txn.query(table, where: 'date=? AND type=? AND service=? AND title=? AND COALESCE(fund_name,\'\')=COALESCE(?,\'\')', whereArgs: [r['date'],r['type'],r['service'],r['title'],r['fund_name']], limit: 1)
              : await txn.query(table, where: 'date=? AND category=? AND COALESCE(fund_name,\'\')=COALESCE(?,\'\') AND COALESCE(note,\'\')=COALESCE(?,\'\')', whereArgs: [r['date'],r['category'],r['fund_name'],r['note']], limit: 1);
          if (existing.isNotEmpty) { batchMap[(rawRow['id'] as num).toInt()] = (existing.first['id'] as num).toInt(); skipped++; continue; }
          final id = await txn.insert(table, r); batchMap[(rawRow['id'] as num).toInt()] = id; imported++;
        }
      }
      // Child rows are deduped by batch + business fields, so importing the same package twice is safe.
      for (final table in ['fungu_contributions','other_contributions','expenditure_entries']) {
        for (final rawRow in (data[table] as List).cast<Map>()) {
          final r = Map<String,dynamic>.from(rawRow);
          final oldBatch = (r['batch_id'] as num).toInt();
          final newBatch = batchMap[oldBatch];
          if (newBatch == null) { conflicts++; continue; }
          r.remove('id'); r['batch_id'] = newBatch;
          String where; List<Object?> args;
          if (table == 'fungu_contributions') {
            where='batch_id=? AND envelope_no=? AND amount=? AND receipt_no=?'; args=[newBatch,r['envelope_no'],r['amount'],r['receipt_no']];
          } else if (table == 'other_contributions') {
            where='batch_id=? AND name_no=? AND amount=? AND receipt_no=?'; args=[newBatch,r['name_no'],r['amount'],r['receipt_no']];
          } else {
            where='batch_id=? AND description=? AND amount=? AND COALESCE(reference,\'\')=COALESCE(?,\'\')'; args=[newBatch,r['description'],r['amount'],r['reference']];
          }
          final exists=await txn.query(table,where:where,whereArgs:args,limit:1);
          if(exists.isEmpty){await txn.insert(table,r); imported++;}else{skipped++;}
        }
      }
    });
    await AppDb.instance.audit('SYNC_IMPORTED','imported=$imported; skipped=$skipped; conflicts=$conflicts; source=${pkg['device_id']}');
    return SyncResult(imported: imported, skipped: skipped, conflicts: conflicts);
  }

  static Future<void> _write(String path, String value) async {
    // imported lazily to keep this service testable
    final f = File(path); await f.writeAsString(value, flush: true);
  }
  static Future<String> _read(String path) async => await File(path).readAsString();
}
