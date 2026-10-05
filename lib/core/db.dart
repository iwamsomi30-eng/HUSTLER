import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Database ya ndani (offline). Schema ina settings, audit log na data ya michango ya Stage 2.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;
  Database get db => _db!;

  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final path = p.join(dir.path, 'mfuko_wa_kanisa.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
        // Kumbukumbu ya mabadiliko (audit log): nani alifanya nini na lini.
        await db.execute('''CREATE TABLE audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            at TEXT NOT NULL,
            action TEXT NOT NULL,
            detail TEXT)''');
        await _createContributionTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createContributionTables(db);
          await auditDb(db, 'DB_UPGRADED', 'schema=2');
        }
      },
    );
  }


  static Future<void> _createContributionTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS contribution_batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      type TEXT NOT NULL,
      service INTEGER NOT NULL,
      title TEXT NOT NULL,
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS fungu_contributions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      batch_id INTEGER NOT NULL,
      envelope_no TEXT NOT NULL,
      donor_name TEXT,
      contact TEXT,
      amount REAL NOT NULL,
      receipt_no TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY(batch_id) REFERENCES contribution_batches(id)
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS other_contributions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      batch_id INTEGER NOT NULL,
      contribution_name TEXT NOT NULL,
      donor_name TEXT NOT NULL,
      name_no TEXT NOT NULL,
      contact TEXT,
      amount REAL NOT NULL,
      receipt_no TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY(batch_id) REFERENCES contribution_batches(id)
    )''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_contribution_batches_date ON contribution_batches(date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_fungu_batch ON fungu_contributions(batch_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_other_batch ON other_contributions(batch_id)');
  }

  static Future<void> auditDb(Database db, String action, String detail) async {
    await db.insert('audit_log', {
      'at': DateTime.now().toIso8601String(),
      'action': action,
      'detail': detail,
    });
  }

  Future<int> createContributionBatch({
    required String date,
    required String type,
    required int service,
    required String title,
  }) async {
    return db.insert('contribution_batches', {
      'date': date,
      'type': type,
      'service': service,
      'title': title,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> saveFunguBatch({
    required String date,
    required int service,
    required String title,
    required List<Map<String, Object?>> rows,
  }) async {
    return db.transaction<int>((txn) async {
      final batchId = await txn.insert('contribution_batches', {
        'date': date,
        'type': 'FUNGU',
        'service': service,
        'title': title,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final row in rows) {
        await txn.insert('fungu_contributions', {
          'batch_id': batchId,
          'envelope_no': row['envelopeNo'],
          'donor_name': row['donorName'],
          'contact': row['contact'],
          'amount': row['amount'],
          'receipt_no': row['receiptNo'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      return batchId;
    });
  }

  Future<int> saveOtherBatch({
    required String date,
    required int service,
    required String title,
    required List<Map<String, Object?>> rows,
  }) async {
    return db.transaction<int>((txn) async {
      final batchId = await txn.insert('contribution_batches', {
        'date': date,
        'type': 'OTHER',
        'service': service,
        'title': title,
        'created_at': DateTime.now().toIso8601String(),
      });
      final countRows =
          await txn.rawQuery('SELECT COUNT(*) AS c FROM other_contributions');
      var nextNumber = (countRows.first['c'] as int? ?? 0) + 1;
      for (final row in rows) {
        final nameNo = 'MCH-${nextNumber.toString().padLeft(5, '0')}';
        nextNumber++;
        await txn.insert('other_contributions', {
          'batch_id': batchId,
          'contribution_name': row['contributionName'],
          'donor_name': row['donorName'],
          'name_no': nameNo,
          'contact': row['contact'],
          'amount': row['amount'],
          'receipt_no': row['receiptNo'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      return batchId;
    });
  }

  Future<int> addFunguContribution({
    required int batchId,
    required String envelopeNo,
    required String donorName,
    required String contact,
    required double amount,
    required String receiptNo,
  }) async {
    return db.insert('fungu_contributions', {
      'batch_id': batchId,
      'envelope_no': envelopeNo.trim(),
      'donor_name': donorName.trim().isEmpty ? null : donorName.trim(),
      'contact': contact.trim().isEmpty ? null : contact.trim(),
      'amount': amount,
      'receipt_no': receiptNo,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> addOtherContribution({
    required int batchId,
    required String contributionName,
    required String donorName,
    required String nameNo,
    required String contact,
    required double amount,
    required String receiptNo,
  }) async {
    return db.insert('other_contributions', {
      'batch_id': batchId,
      'contribution_name': contributionName.trim(),
      'donor_name': donorName.trim(),
      'name_no': nameNo,
      'contact': contact.trim().isEmpty ? null : contact.trim(),
      'amount': amount,
      'receipt_no': receiptNo,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> nextDonorNumber() async {
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM other_contributions');
    final count = (rows.first['c'] as int? ?? 0) + 1;
    return 'MCH-${count.toString().padLeft(5, '0')}';
  }

  Future<List<Map<String, Object?>>> getContributionDaySummaries({
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('b.date >= ?');
      args.add(DateTime(from.year, from.month, from.day).toIso8601String());
    }
    if (to != null) {
      where.add('b.date < ?');
      args.add(DateTime(to.year, to.month, to.day + 1).toIso8601String());
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      where.add('(b.title LIKE ? OR f.envelope_no LIKE ? OR f.donor_name LIKE ? OR f.contact LIKE ? OR f.receipt_no LIKE ? OR o.name_no LIKE ? OR o.donor_name LIKE ? OR o.contribution_name LIKE ? OR o.contact LIKE ? OR o.receipt_no LIKE ?)');
      args.addAll(List<Object?>.filled(10, q));
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT substr(b.date, 1, 10) AS day,
        COUNT(DISTINCT b.id) AS batches,
        COALESCE((SELECT COUNT(*) FROM fungu_contributions f2 JOIN contribution_batches bx ON bx.id=f2.batch_id WHERE substr(bx.date,1,10)=substr(b.date,1,10)),0)
          + COALESCE((SELECT COUNT(*) FROM other_contributions o2 JOIN contribution_batches bo ON bo.id=o2.batch_id WHERE substr(bo.date,1,10)=substr(b.date,1,10)),0) AS entries,
        COALESCE((SELECT SUM(f3.amount) FROM fungu_contributions f3 JOIN contribution_batches bz ON bz.id=f3.batch_id WHERE substr(bz.date,1,10)=substr(b.date,1,10)),0)
          + COALESCE((SELECT SUM(o3.amount) FROM other_contributions o3 JOIN contribution_batches bw ON bw.id=o3.batch_id WHERE substr(bw.date,1,10)=substr(b.date,1,10)),0) AS total
      FROM contribution_batches b
      LEFT JOIN fungu_contributions f ON f.batch_id=b.id
      LEFT JOIN other_contributions o ON o.batch_id=b.id
      $whereSql
      GROUP BY substr(b.date,1,10)
      ORDER BY day DESC
    ''', args);
    return rows;
  }

  Future<List<Map<String, Object?>>> getContributionDetailsForDay(String day) async {
    return db.rawQuery('''
      SELECT b.id AS batch_id, b.date, b.type, b.service, b.title, b.created_at,
             f.id AS row_id, f.envelope_no, f.donor_name, f.contact, f.amount,
             f.receipt_no, NULL AS contribution_name, NULL AS name_no
      FROM contribution_batches b
      JOIN fungu_contributions f ON f.batch_id=b.id
      WHERE substr(b.date,1,10)=?
      UNION ALL
      SELECT b.id AS batch_id, b.date, b.type, b.service, b.title, b.created_at,
             o.id AS row_id, NULL AS envelope_no, o.donor_name, o.contact, o.amount,
             o.receipt_no, o.contribution_name, o.name_no
      FROM contribution_batches b
      JOIN other_contributions o ON o.batch_id=b.id
      WHERE substr(b.date,1,10)=?
      ORDER BY service ASC, type ASC, batch_id ASC, row_id ASC
    ''', [day, day]);
  }

  Future<int> updateFunguContribution({required int id, required String envelopeNo, required String donorName, required String contact, required double amount}) async {
    final count = await db.update('fungu_contributions', {
      'envelope_no': envelopeNo.trim(),
      'donor_name': donorName.trim().isEmpty ? null : donorName.trim(),
      'contact': contact.trim().isEmpty ? null : contact.trim(),
      'amount': amount,
    }, where: 'id = ?', whereArgs: [id]);
    await audit('CONTRIBUTION_FUNGU_UPDATED', 'id=$id; amount=$amount');
    return count;
  }

  Future<int> updateOtherContribution({required int id, required String contributionName, required String donorName, required String contact, required double amount}) async {
    final count = await db.update('other_contributions', {
      'contribution_name': contributionName.trim(),
      'donor_name': donorName.trim(),
      'contact': contact.trim().isEmpty ? null : contact.trim(),
      'amount': amount,
    }, where: 'id = ?', whereArgs: [id]);
    await audit('CONTRIBUTION_OTHER_UPDATED', 'id=$id; amount=$amount');
    return count;
  }

  Future<Map<String, Object?>> contributionDayStats(String day) async {
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM fungu_contributions f JOIN contribution_batches b ON b.id=f.batch_id WHERE substr(b.date,1,10)=?) AS fungu_count,
        (SELECT COALESCE(SUM(f.amount),0) FROM fungu_contributions f JOIN contribution_batches b ON b.id=f.batch_id WHERE substr(b.date,1,10)=?) AS fungu_total,
        (SELECT COUNT(*) FROM other_contributions o JOIN contribution_batches b ON b.id=o.batch_id WHERE substr(b.date,1,10)=?) AS other_count,
        (SELECT COALESCE(SUM(o.amount),0) FROM other_contributions o JOIN contribution_batches b ON b.id=o.batch_id WHERE substr(b.date,1,10)=?) AS other_total
    ''', [day, day, day, day]);
    return rows.isEmpty ? {} : rows.first;
  }

  Future<String?> getSetting(String key) async {
    final rows =
        await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> audit(String action, [String? detail]) async {
    await db.insert('audit_log', {
      'at': DateTime.now().toIso8601String(),
      'action': action,
      'detail': detail,
    });
  }
}
