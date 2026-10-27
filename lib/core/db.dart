import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'dart:convert' show utf8;
import 'receipt.dart';

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
      version: 8,
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
        await _createExpenditureTables(db);
        await _addFundToContributions(db);
        await _addSyncSchema(db);
        await _addStep2Schema(db);
        await _addCorrectionSchema(db);
        await _addDonorsSchema(db);
        await _addBroadcastSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createContributionTables(db);
          await auditDb(db, 'DB_UPGRADED', 'schema=2');
        }
        if (oldVersion < 3) {
          await _createExpenditureTables(db);
          await auditDb(db, 'DB_UPGRADED', 'schema=3');
        }
        if (oldVersion < 4) {
          await _addFundToContributions(db);
          await auditDb(db, 'DB_UPGRADED', 'schema=4; fund ledger');
        }
        if (oldVersion < 5) {
          await _addSyncSchema(db);
          await auditDb(db, 'DB_UPGRADED', 'schema=5; secure cloud sync');
        }
        if (oldVersion < 6) {
          await _addStep2Schema(db);
          await auditDb(db, 'DB_UPGRADED', 'schema=6; sex field and custom names');
        }
        if (oldVersion < 7) {
          await _addCorrectionSchema(db);
          await auditDb(db, 'DB_UPGRADED', 'schema=7; correction messages');
        }
        if (oldVersion < 8) {
          await _addDonorsSchema(db);
          await _addBroadcastSchema(db);
          await auditDb(db, 'DB_UPGRADED', 'schema=8; donor registry and emergency messages');
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

  static Future<void> _addFundToContributions(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(contribution_batches)');
    final exists = cols.any((r) => '${r['name']}' == 'fund_name');
    if (!exists) await db.execute('ALTER TABLE contribution_batches ADD COLUMN fund_name TEXT');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contribution_batches_fund ON contribution_batches(fund_name)');
  }

  static Future<void> _createExpenditureTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS expenditure_batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      category TEXT NOT NULL,
      fund_name TEXT,
      note TEXT,
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS expenditure_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      batch_id INTEGER NOT NULL,
      description TEXT NOT NULL,
      payee TEXT,
      reference TEXT,
      amount REAL NOT NULL CHECK(amount > 0),
      created_at TEXT NOT NULL,
      FOREIGN KEY(batch_id) REFERENCES expenditure_batches(id) ON DELETE CASCADE
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenditure_batches_date ON expenditure_batches(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenditure_batches_category ON expenditure_batches(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenditure_entries_batch ON expenditure_entries(batch_id)');
  }

  static const _uuid = Uuid();
  static const _syncTables = <String>[
    'contribution_batches', 'fungu_contributions', 'other_contributions',
    'expenditure_batches', 'expenditure_entries', 'donors'
  ];

  /// Hatua ya 2: safu ya jinsia kwenye michango na jedwali la majina yaliyoongezwa na mtumiaji.
  static Future<void> _addStep2Schema(Database db) async {
    for (final table in const ['fungu_contributions', 'other_contributions']) {
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      final names = cols.map((r) => '${r['name']}').toSet();
      if (!names.contains('sex')) await db.execute('ALTER TABLE $table ADD COLUMN sex TEXT');
    }
    await db.execute('''CREATE TABLE IF NOT EXISTS custom_names (
      kind TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY(kind, name)
    )''');
  }

  /// Hatua ya 3: historia ya jumbe za marekebisho zilizotumwa kwa wachangiaji.
  /// Jedwali hili ni la ndani ya kifaa tu; halihusiani na sync ya michango.
  static Future<void> _addCorrectionSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS correction_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receipt_no TEXT NOT NULL,
      donor_name TEXT,
      contact TEXT,
      message TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_correction_receipt ON correction_messages(receipt_no)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_correction_created ON correction_messages(created_at)');
  }

  // ---------------------------------------------------------------------------
  // Usajili wa watu (donors) na jumbe za dharura
  // ---------------------------------------------------------------------------

  /// Jinsia zinazokubalika: KE, ME, na ME&KE (mume na mke - mchango wa pamoja).
  static const validSexes = <String>['KE', 'ME', 'ME&KE'];

  /// Jina la mtu lililosanifishwa: herufi kubwa, nafasi moja kati ya maneno.
  static String donorKey(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  /// Kitambulisho cha usawazishaji (UUID) kinachotokana na jina. Vifaa viwili vikimsajili
  /// mtu mmoja (jina moja) vinapata kitambulisho kimoja, kwa hiyo hakuna nakala mbili.
  static String donorSyncId(String name) {
    final d = sha256.convert(utf8.encode('hustler-donor:${donorKey(name)}')).bytes;
    final b = List<int>.from(d.sublist(0, 16));
    b[6] = (b[6] & 0x0f) | 0x50; // toleo 5
    b[8] = (b[8] & 0x3f) | 0x80; // variant
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }

  static Future<void> _addDonorsSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS donors (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      sex TEXT,
      contact TEXT,
      envelope_no TEXT,
      created_at TEXT NOT NULL,
      sync_id TEXT,
      updated_at TEXT
    )''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_donors_sync_id ON donors(sync_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_donors_updated_at ON donors(updated_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_donors_name ON donors(name)');
    await _backfillDonors(db);
  }

  /// Watoaji waliokwisha kuwepo kwenye michango ya zamani wanaingizwa kwenye orodha ya
  /// waliosajiliwa, ili waonekane kwenye utafutaji bila kusajiliwa upya.
  static Future<void> _backfillDonors(Database db) async {
    final rows = <Map<String, Object?>>[];
    try {
      rows.addAll(await db.rawQuery(
          "SELECT donor_name AS name, sex, contact, envelope_no AS env, created_at AS at FROM fungu_contributions WHERE TRIM(COALESCE(donor_name,'')) <> ''"));
      rows.addAll(await db.rawQuery(
          "SELECT donor_name AS name, sex, contact, NULL AS env, created_at AS at FROM other_contributions WHERE TRIM(COALESCE(donor_name,'')) <> ''"));
    } catch (_) {
      return;
    }
    rows.sort((a, b) => '${a['at']}'.compareTo('${b['at']}'));
    final byKey = <String, Map<String, String>>{};
    for (final r in rows) {
      final key = donorKey('${r['name']}');
      if (key.isEmpty) continue;
      final m = byKey.putIfAbsent(key, () => {'name': key, 'sex': '', 'contact': '', 'env': '', 'at': '${r['at']}'});
      final sex = '${r['sex'] ?? ''}'.trim();
      final contact = '${r['contact'] ?? ''}'.trim();
      final env = '${r['env'] ?? ''}'.trim();
      if (validSexes.contains(sex)) m['sex'] = sex;
      if (contact.isNotEmpty) m['contact'] = contact;
      if (env.isNotEmpty) m['env'] = env;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    for (final m in byKey.values) {
      final exists = await db.query('donors', columns: ['id'], where: 'UPPER(name) = ?', whereArgs: [m['name']], limit: 1);
      if (exists.isNotEmpty) continue;
      await db.insert('donors', {
        'name': m['name'],
        'sex': m['sex']!.isEmpty ? null : m['sex'],
        'contact': m['contact']!.isEmpty ? null : m['contact'],
        'envelope_no': m['env']!.isEmpty ? null : m['env'],
        'created_at': m['at'],
        'sync_id': donorSyncId(m['name']!),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Jumbe za dharura zilizotumwa (historia ya kifaa hiki tu; haisawazishwi).
  static Future<void> _addBroadcastSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS broadcast_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message TEXT NOT NULL,
      recipients INTEGER NOT NULL,
      sent INTEGER NOT NULL,
      failed INTEGER NOT NULL,
      invalid INTEGER NOT NULL,
      names TEXT,
      created_at TEXT NOT NULL
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_broadcast_created ON broadcast_messages(created_at)');
  }

  Future<int> donorCount() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM donors');
    return (r.first['c'] as num?)?.toInt() ?? 0;
  }

  /// Tafuta waliosajiliwa kwa jina, namba ya simu au namba ya bahasha. Tupu = wote.
  Future<List<Map<String, Object?>>> searchDonors(String query, {int limit = 500}) async {
    final q = query.trim().toUpperCase().replaceAll('%', '').replaceAll('_', '');
    if (q.isEmpty) {
      return db.query('donors', orderBy: 'name COLLATE NOCASE ASC', limit: limit);
    }
    final like = '%$q%';
    return db.query(
      'donors',
      where: "UPPER(name) LIKE ? OR UPPER(IFNULL(contact,'')) LIKE ? OR UPPER(IFNULL(envelope_no,'')) LIKE ?",
      whereArgs: [like, like, like],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
    );
  }

  Future<Map<String, Object?>?> getDonor(int id) async {
    final r = await db.query('donors', where: 'id=?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, Object?>?> findDonorByName(String name) async {
    final r = await db.query('donors', where: 'UPPER(name) = ?', whereArgs: [donorKey(name)], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  /// Inasajili mtu mpya. Inatupa StateError('donor_exists') kama jina lipo tayari.
  Future<Map<String, Object?>> registerDonor({
    required String name,
    required String sex,
    String contact = '',
    String envelopeNo = '',
  }) async {
    await _ensureWritable();
    final key = donorKey(name);
    if (key.length < 2) throw ArgumentError('donor_name_required');
    if (!validSexes.contains(sex)) throw ArgumentError('donor_sex_required');
    if (await findDonorByName(key) != null) throw StateError('donor_exists');
    final syncId = donorSyncId(key);
    final now = _now();
    final id = await db.transaction<int>((txn) async {
      await txn.delete('sync_tombstones', where: 'entity_type=? AND sync_id=?', whereArgs: ['donors', syncId]);
      await txn.delete('donors', where: 'sync_id=?', whereArgs: [syncId]);
      return txn.insert('donors', {
        'name': key,
        'sex': sex,
        'contact': contact.trim().isEmpty ? null : contact.trim(),
        'envelope_no': envelopeNo.trim().isEmpty ? null : envelopeNo.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'sync_id': syncId,
        'updated_at': now,
      });
    });
    await _markSyncDirty();
    await audit('DONOR_REGISTERED', 'id=$id; name=$key');
    return (await getDonor(id))!;
  }

  /// Inabadilisha usajili wa mtu. Mabadiliko ya jina/jinsia/simu yanapelekwa pia kwenye
  /// michango yake yote iliyokwisha kuhifadhiwa, ili jedwali la watoaji libaki kwenye mstari mmoja.
  Future<Map<String, Object?>> updateDonor({
    required int id,
    required String name,
    required String sex,
    String contact = '',
    String envelopeNo = '',
  }) async {
    await _ensureWritable();
    final key = donorKey(name);
    if (key.length < 2) throw ArgumentError('donor_name_required');
    if (!validSexes.contains(sex)) throw ArgumentError('donor_sex_required');
    final old = await getDonor(id);
    if (old == null) throw StateError('donor_missing');
    final oldKey = donorKey('${old['name']}');
    if (key != oldKey) {
      final dup = await findDonorByName(key);
      if (dup != null && (dup['id'] as num).toInt() != id) throw StateError('donor_exists');
    }
    final now = _now();
    final contactV = contact.trim().isEmpty ? null : contact.trim();
    final envV = envelopeNo.trim().isEmpty ? null : envelopeNo.trim();
    await db.transaction((txn) async {
      await txn.update('donors', {
        'name': key,
        'sex': sex,
        'contact': contactV,
        'envelope_no': envV,
        'updated_at': now,
      }, where: 'id=?', whereArgs: [id]);
      for (final table in const ['fungu_contributions', 'other_contributions']) {
        final rows = await txn.query(table, columns: ['id', 'donor_name'], where: "TRIM(COALESCE(donor_name,'')) <> ''");
        for (final r in rows) {
          if (donorKey('${r['donor_name']}') != oldKey) continue;
          await txn.update(table, {
            'donor_name': key,
            'sex': sex,
            'contact': contactV,
            if (table == 'fungu_contributions' && envV != null) 'envelope_no': envV,
            'updated_at': now,
          }, where: 'id=?', whereArgs: [r['id']]);
        }
      }
    });
    await _markSyncDirty();
    await audit('DONOR_UPDATED', 'id=$id; name=$key');
    return (await getDonor(id))!;
  }

  /// Inafuta usajili tu; michango ambayo mtu huyo alishatoa haiguswi.
  Future<void> deleteDonor(int id) async {
    await _ensureWritable();
    final old = await getDonor(id);
    if (old == null) return;
    final now = _now();
    await db.transaction((txn) async {
      await txn.insert('sync_tombstones', {'entity_type': 'donors', 'sync_id': old['sync_id'], 'deleted_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('donors', where: 'id=?', whereArgs: [id]);
    });
    await _markSyncDirty();
    await audit('DONOR_DELETED', 'id=$id; name=${old['name']}');
  }

  /// Baada ya mchango kuhifadhiwa: inajaza tu sehemu zilizokuwa tupu kwenye usajili
  /// (jinsia, simu, namba ya bahasha). Haibadilishi zilizokwisha kuwepo.
  Future<void> fillDonorBlanks({required String name, String sex = '', String contact = '', String envelopeNo = ''}) async {
    final d = await findDonorByName(name);
    if (d == null) return;
    final patch = <String, Object?>{};
    if ('${d['sex'] ?? ''}'.isEmpty && validSexes.contains(sex)) patch['sex'] = sex;
    if ('${d['contact'] ?? ''}'.trim().isEmpty && contact.trim().isNotEmpty) patch['contact'] = contact.trim();
    if ('${d['envelope_no'] ?? ''}'.trim().isEmpty && envelopeNo.trim().isNotEmpty) patch['envelope_no'] = envelopeNo.trim();
    if (patch.isEmpty) return;
    patch['updated_at'] = _now();
    await db.update('donors', patch, where: 'id=?', whereArgs: [d['id']]);
    await _markSyncDirty();
  }

  Future<int> addBroadcast({
    required String message,
    required int recipients,
    required int sent,
    required int failed,
    required int invalid,
    required String names,
  }) async {
    return db.insert('broadcast_messages', {
      'message': message,
      'recipients': recipients,
      'sent': sent,
      'failed': failed,
      'invalid': invalid,
      'names': names,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getBroadcasts({int limit = 30}) =>
      db.query('broadcast_messages', orderBy: 'created_at DESC, id DESC', limit: limit);


  /// Inatafuta mchango kwa namba ya risiti (herufi kubwa/ndogo hazijalishi).
  /// Inarudisha null kama risiti haipo.
  Future<Map<String, Object?>?> findContributionByReceipt(String receiptNo) async {
    final key = receiptNo.trim().toUpperCase();
    if (key.isEmpty) return null;
    final rows = await db.rawQuery('''
      SELECT 'FUNGU' AS kind, f.receipt_no AS receipt_no, f.donor_name AS donor_name,
             f.contact AS contact, f.amount AS amount, b.date AS date,
             b.fund_name AS fund_name, 'FUNGU' AS purpose, f.envelope_no AS ref_no
        FROM fungu_contributions f
        JOIN contribution_batches b ON b.id = f.batch_id
       WHERE UPPER(TRIM(f.receipt_no)) = ?
      UNION ALL
      SELECT 'OTHER' AS kind, o.receipt_no, o.donor_name, o.contact, o.amount, b.date,
             b.fund_name, o.contribution_name AS purpose, o.name_no AS ref_no
        FROM other_contributions o
        JOIN contribution_batches b ON b.id = o.batch_id
       WHERE UPPER(TRIM(o.receipt_no)) = ?
       LIMIT 1
    ''', [key, key]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Marekebisho: tafuta kwa jina la mtoaji au namba ya kipekee (namba ya bahasha /
  /// namba ya mtoaji). Namba ya risiti inakubaliwa pia. Inarudisha rekodi zote zinazolingana.
  Future<List<Map<String, Object?>>> searchContributionsForCorrection(String query, {int limit = 40}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final up = q.toUpperCase();
    final like = '%${up.replaceAll('%', '').replaceAll('_', '')}%';
    return db.rawQuery('''
      SELECT * FROM (
        SELECT 'FUNGU' AS kind, f.receipt_no AS receipt_no, f.donor_name AS donor_name,
               f.contact AS contact, f.amount AS amount, b.date AS date,
               b.fund_name AS fund_name, 'FUNGU' AS purpose, f.envelope_no AS ref_no
          FROM fungu_contributions f
          JOIN contribution_batches b ON b.id = f.batch_id
         WHERE UPPER(TRIM(f.envelope_no)) = ? OR UPPER(IFNULL(f.donor_name,'')) LIKE ?
            OR UPPER(TRIM(f.receipt_no)) = ?
        UNION ALL
        SELECT 'OTHER' AS kind, o.receipt_no, o.donor_name, o.contact, o.amount, b.date,
               b.fund_name, o.contribution_name AS purpose, o.name_no AS ref_no
          FROM other_contributions o
          JOIN contribution_batches b ON b.id = o.batch_id
         WHERE UPPER(TRIM(o.name_no)) = ? OR UPPER(IFNULL(o.donor_name,'')) LIKE ?
            OR UPPER(TRIM(o.receipt_no)) = ?
      ) ORDER BY date DESC, receipt_no DESC
      LIMIT ?
    ''', [up, like, up, up, like, up, limit]);
  }

  Future<int> addCorrectionMessage({
    required String receiptNo,
    required String donorName,
    required String contact,
    required String message,
    required String status,
  }) async {
    return db.insert('correction_messages', {
      'receipt_no': receiptNo.trim(),
      'donor_name': donorName.trim(),
      'contact': contact.trim(),
      'message': message,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getCorrectionMessages({int limit = 100}) async {
    return db.query('correction_messages', orderBy: 'created_at DESC, id DESC', limit: limit);
  }

  /// Majina yaliyoongezwa na mtumiaji. kind = 'contribution' au 'expenditure'.
  Future<List<String>> customNames(String kind) async {
    final rows = await db.query('custom_names', columns: ['name'], where: 'kind=?', whereArgs: [kind], orderBy: 'created_at ASC');
    return [for (final r in rows) '${r['name']}'];
  }

  Future<void> addCustomName(String kind, String name) async {
    await db.insert('custom_names', {'kind': kind, 'name': name, 'created_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Majina ya michango yaliyokwisha kutumika kwenye rekodi (huhamishwa pia na sync).
  Future<List<String>> usedContributionNames() async {
    final rows = await db.rawQuery(
        "SELECT DISTINCT TRIM(contribution_name) AS n FROM other_contributions WHERE TRIM(COALESCE(contribution_name,'')) <> '' ORDER BY n");
    return [for (final r in rows) '${r['n']}'];
  }

  /// Majina ya matumizi yaliyokwisha kutumika kwenye rekodi (yakiwemo ya zamani).
  Future<List<String>> usedExpenditureNames() async {
    final rows = await db.rawQuery(
        "SELECT DISTINCT TRIM(category) AS n FROM expenditure_batches WHERE TRIM(COALESCE(category,'')) <> '' ORDER BY n");
    return [for (final r in rows) '${r['n']}'];
  }

  static Future<void> _addSyncSchema(Database db) async {
    await db.execute("""CREATE TABLE IF NOT EXISTS sync_tombstones (
      entity_type TEXT NOT NULL,
      sync_id TEXT NOT NULL,
      deleted_at TEXT NOT NULL,
      PRIMARY KEY(entity_type, sync_id)
    )""");
    for (final table in _syncTables) {
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      if (cols.isEmpty) continue; // jedwali bado halijatengenezwa (mf. 'donors' kwenye DB za zamani)
      final names = cols.map((r) => '${r['name']}').toSet();
      if (!names.contains('sync_id')) await db.execute('ALTER TABLE $table ADD COLUMN sync_id TEXT');
      if (!names.contains('updated_at')) await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
      final rows = await db.query(table, columns: ['id','sync_id','created_at','updated_at']);
      for (final r in rows) {
        if (r['sync_id'] == null || '${r['sync_id']}'.isEmpty) await db.update(table, {'sync_id': _uuid.v4()}, where: 'id=?', whereArgs: [r['id']]);
        if (r['updated_at'] == null) await db.update(table, {'updated_at': r['created_at'] ?? DateTime.now().toUtc().toIso8601String()}, where: 'id=?', whereArgs: [r['id']]);
      }
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_${table}_sync_id ON $table(sync_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_${table}_updated_at ON $table(updated_at)');
    }
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<void> _ensureWritable() async {
    // All actively linked devices are full peers.
    // A legacy `viewer` role is still allowed to write locally so an old
    // pairing can be upgraded by the next cloud sync instead of blocking
    // the user with READ_ONLY_ACCESS.
  }

  Future<void> _markSyncDirty() async {
    await setSetting('cloud_sync_dirty', DateTime.now().toUtc().toIso8601String());
  }

  Future<String> _newSyncId() async => _uuid.v4();

  Future<List<Map<String, Object?>>> syncRows({DateTime? since}) async {
    final out = <Map<String,Object?>>[];
    for (final table in _syncTables) {
      final rows = await db.query(table, where: since == null ? null : 'updated_at > ?', whereArgs: since == null ? null : [since.toUtc().toIso8601String()]);
      for (final row in rows) {
        final payload = Map<String,dynamic>.from(row);
        payload.remove('id'); payload.remove('sync_id'); payload.remove('updated_at');
        if (table == 'fungu_contributions' || table == 'other_contributions' || table == 'expenditure_entries') {
          final parentTable = table == 'expenditure_entries' ? 'expenditure_batches' : 'contribution_batches';
          final parent = await db.query(parentTable, columns: ['sync_id'], where: 'id=?', whereArgs: [row['batch_id']], limit: 1);
          payload['parent_sync_id'] = parent.isEmpty ? null : parent.first['sync_id'];
        }
        out.add({'entity_type': table, 'sync_id': row['sync_id'], 'updated_at': row['updated_at'], 'deleted': false, 'payload': payload});
      }
    }
    for (final t in await db.query('sync_tombstones', where: since == null ? null : 'deleted_at > ?', whereArgs: since == null ? null : [since.toUtc().toIso8601String()])) {
      out.add({'entity_type': t['entity_type'], 'sync_id': t['sync_id'], 'updated_at': t['deleted_at'], 'deleted': true, 'payload': <String,dynamic>{}});
    }
    return out;
  }

  Future<bool> applyRemoteSyncRow({required String entityType, required String syncId, required String updatedAt, required bool deleted, required Map<String,dynamic> payload}) async {
    if (!_syncTables.contains(entityType)) return false;
    final table = entityType;
    final local = await db.query(table, where: 'sync_id=?', whereArgs: [syncId], limit: 1);
    final localUpdated = local.isEmpty ? null : DateTime.tryParse('${local.first['updated_at'] ?? ''}');
    final remoteUpdated = DateTime.tryParse(updatedAt);
    if (localUpdated != null && remoteUpdated != null && !remoteUpdated.isAfter(localUpdated)) return false;
    if (deleted) {
      if (local.isNotEmpty) await db.delete(table, where: 'sync_id=?', whereArgs: [syncId]);
      await db.insert('sync_tombstones', {'entity_type': table, 'sync_id': syncId, 'deleted_at': updatedAt}, conflictAlgorithm: ConflictAlgorithm.replace);
      return local.isNotEmpty;
    }
    final data = Map<String,dynamic>.from(payload)..remove('parent_sync_id');
    data['sync_id'] = syncId; data['updated_at'] = updatedAt;
    if (table == 'fungu_contributions' || table == 'other_contributions' || table == 'expenditure_entries') {
      final parentSync = payload['parent_sync_id'];
      if (parentSync == null) return false;
      final parentTable = table == 'expenditure_entries' ? 'expenditure_batches' : 'contribution_batches';
      final parent = await db.query(parentTable, columns: ['id'], where: 'sync_id=?', whereArgs: [parentSync], limit: 1);
      if (parent.isEmpty) return false;
      data['batch_id'] = parent.first['id'];
    }
    data.remove('id');
    final known = (await db.rawQuery('PRAGMA table_info($table)')).map((r) => '${r['name']}').toSet();
    data.removeWhere((k, _) => !known.contains(k));
    if (local.isEmpty) await db.insert(table, data); else await db.update(table, data, where: 'sync_id=?', whereArgs: [syncId]);
    await db.delete('sync_tombstones', where: 'entity_type=? AND sync_id=?', whereArgs: [table, syncId]);
    return true;
  }

  Future<int> saveExpenditureBatch({
    required String date, required String category, required String fundName,
    required String note, required List<Map<String, Object?>> rows,
  }) async {
    await _ensureWritable();
    if (rows.isEmpty) throw ArgumentError('At least one expenditure row is required');
    final batchId = await db.transaction<int>((txn) async {
      final batchId = await txn.insert('expenditure_batches', {
        'date': date, 'category': category,
        'fund_name': fundName.trim().isEmpty ? null : fundName.trim(),
        'note': note.trim().isEmpty ? null : note.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'sync_id': _uuid.v4(), 'updated_at': _now(),
      });
      for (final row in rows) {
        await txn.insert('expenditure_entries', {
          'batch_id': batchId,
          'description': row['description'],
          'payee': (row['payee'] as String?)?.trim().isEmpty == true ? null : (row['payee'] as String?)?.trim(),
          'reference': (row['reference'] as String?)?.trim().isEmpty == true ? null : (row['reference'] as String?)?.trim(),
          'amount': row['amount'],
          'created_at': DateTime.now().toIso8601String(),
          'sync_id': _uuid.v4(), 'updated_at': _now(),
        });
      }
      return batchId;
    });
    await _markSyncDirty();
    return batchId;
  }

  Future<List<Map<String, Object?>>> getExpenditureSummary({String? search, DateTime? from, DateTime? to}) async {
    final where=<String>[]; final args=<Object?>[];
    if(from!=null){where.add('b.date >= ?'); args.add(DateTime(from.year,from.month,from.day).toIso8601String());}
    if(to!=null){where.add('b.date < ?'); args.add(DateTime(to.year,to.month,to.day+1).toIso8601String());}
    if(search!=null && search.trim().isNotEmpty){where.add('(b.category LIKE ? OR b.fund_name LIKE ? OR e.description LIKE ? OR e.payee LIKE ? OR e.reference LIKE ?)'); final q='%${search.trim()}%'; args.addAll([q,q,q,q,q]);}
    final ws=where.isEmpty?'':'WHERE ${where.join(' AND ')}';
    return db.rawQuery('''SELECT substr(b.date,1,10) day, b.category, COALESCE(b.fund_name,'') fund_name, COUNT(e.id) entries, COALESCE(SUM(e.amount),0) total
      FROM expenditure_batches b JOIN expenditure_entries e ON e.batch_id=b.id $ws
      GROUP BY substr(b.date,1,10), b.category, b.fund_name ORDER BY day DESC, b.category''', args);
  }

  Future<List<Map<String, Object?>>> getExpenditureDetailsForDay(String day) async => db.rawQuery('''
    SELECT b.id batch_id,b.date,b.category,b.fund_name,b.note,b.created_at,e.id row_id,e.description,e.payee,e.reference,e.amount
    FROM expenditure_batches b JOIN expenditure_entries e ON e.batch_id=b.id
    WHERE substr(b.date,1,10)=? ORDER BY b.category,e.id
  ''',[day]);


  Future<List<Map<String, Object?>>> getExpenditureCategorySummary({
    DateTime? from,
    DateTime? to,
    String? fundName,
    String? category,
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
    if (fundName != null && fundName.trim().isNotEmpty) {
      where.add('b.fund_name = ?');
      args.add(fundName.trim());
    }
    if (category != null && category.isNotEmpty && category != 'ALL') {
      where.add('b.category = ?');
      args.add(category);
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    return db.rawQuery('''
      SELECT b.category AS category,
             COUNT(DISTINCT b.id) AS batches,
             COUNT(e.id) AS entries,
             COALESCE(SUM(e.amount), 0) AS total
      FROM expenditure_batches b
      JOIN expenditure_entries e ON e.batch_id = b.id
      $whereSql
      GROUP BY b.category
      ORDER BY total DESC, b.category ASC
    ''', args);
  }

  Future<List<Map<String, Object?>>> getExpenditureFundSummary({
    DateTime? from,
    DateTime? to,
    String? category,
    String? fundName,
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
    if (category != null && category.isNotEmpty && category != 'ALL') {
      where.add('b.category = ?');
      args.add(category);
    }
    if (fundName != null && fundName.trim().isNotEmpty) {
      where.add('b.fund_name = ?');
      args.add(fundName.trim());
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    return db.rawQuery('''
      SELECT COALESCE(NULLIF(TRIM(b.fund_name), ''), 'HAKUNA MFUKO ULIOCHAGULIWA') AS fund_name,
             COUNT(DISTINCT b.id) AS batches,
             COUNT(e.id) AS entries,
             COALESCE(SUM(e.amount), 0) AS total
      FROM expenditure_batches b
      JOIN expenditure_entries e ON e.batch_id = b.id
      $whereSql
      GROUP BY COALESCE(NULLIF(TRIM(b.fund_name), ''), 'HAKUNA MFUKO ULIOCHAGULIWA')
      ORDER BY total DESC, fund_name ASC
    ''', args);
  }

  Future<List<Map<String, Object?>>> getExpenditureDailySummary({
    DateTime? from,
    DateTime? to,
    String? fundName,
    String? category,
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
    if (fundName != null && fundName.trim().isNotEmpty) {
      where.add('b.fund_name = ?');
      args.add(fundName.trim());
    }
    if (category != null && category.isNotEmpty && category != 'ALL') {
      where.add('b.category = ?');
      args.add(category);
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    return db.rawQuery('''
      SELECT substr(b.date, 1, 10) AS day,
             COUNT(DISTINCT b.id) AS batches,
             COUNT(e.id) AS entries,
             COALESCE(SUM(e.amount), 0) AS total
      FROM expenditure_batches b
      JOIN expenditure_entries e ON e.batch_id = b.id
      $whereSql
      GROUP BY substr(b.date, 1, 10)
      ORDER BY day ASC
    ''', args);
  }

  Future<List<String>> getExpenditureFundNames() async {
    final rows = await db.rawQuery('''
      SELECT DISTINCT TRIM(fund_name) AS fund_name
      FROM expenditure_batches
      WHERE fund_name IS NOT NULL AND TRIM(fund_name) <> ''
      ORDER BY fund_name COLLATE NOCASE ASC
    ''');
    return rows.map((r) => '${r['fund_name']}'.trim()).where((v) => v.isNotEmpty).toList();
  }

  Future<Map<String, Object?>> getExpenditureOverallStats({
    DateTime? from,
    DateTime? to,
    String? fundName,
    String? category,
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
    if (fundName != null && fundName.trim().isNotEmpty) {
      where.add('b.fund_name = ?');
      args.add(fundName.trim());
    }
    if (category != null && category.isNotEmpty && category != 'ALL') {
      where.add('b.category = ?');
      args.add(category);
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT COUNT(DISTINCT b.id) AS batches,
             COUNT(e.id) AS entries,
             COALESCE(SUM(e.amount), 0) AS total
      FROM expenditure_batches b
      JOIN expenditure_entries e ON e.batch_id = b.id
      $whereSql
    ''', args);
    return rows.isEmpty ? <String, Object?>{} : rows.first;
  }

  Future<List<Map<String, Object?>>> getExpenditureBatches({
    String? search, DateTime? from, DateTime? to, String? category,
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
    if (category != null && category.isNotEmpty && category != 'ALL') {
      where.add('b.category = ?');
      args.add(category);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(b.category LIKE ? OR b.fund_name LIKE ? OR b.note LIKE ? OR e.description LIKE ? OR e.payee LIKE ? OR e.reference LIKE ?)');
      final q = '%${search.trim()}%';
      args.addAll([q, q, q, q, q, q]);
    }
    final ws = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    return db.rawQuery('''
      SELECT b.id, b.date, b.category, COALESCE(b.fund_name,'') AS fund_name,
        COALESCE(b.note,'') AS note, b.created_at, COUNT(e.id) AS entries,
        COALESCE(SUM(e.amount),0) AS total
      FROM expenditure_batches b
      JOIN expenditure_entries e ON e.batch_id=b.id
      $ws
      GROUP BY b.id
      ORDER BY b.date DESC, b.id DESC
    ''', args);
  }

  Future<List<Map<String, Object?>>> getExpenditureBatchDetails(int batchId) async =>
      db.query('expenditure_entries', where: 'batch_id = ?', whereArgs: [batchId], orderBy: 'id ASC');

  Future<void> updateExpenditureBatch({
    required int batchId,
    required String date,
    required String category,
    required String fundName,
    required String note,
    required List<Map<String, Object?>> rows,
  }) async {
    await _ensureWritable();
    if (rows.isEmpty) throw ArgumentError('At least one expenditure row is required');
    await db.transaction((txn) async {
      final now = _now();
      await txn.update('expenditure_batches', {
        'date': date,
        'category': category,
        'fund_name': fundName.trim().isEmpty ? null : fundName.trim(),
        'note': note.trim().isEmpty ? null : note.trim(),
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [batchId]);
      final oldEntries = await txn.query('expenditure_entries', columns: ['sync_id'], where: 'batch_id=?', whereArgs: [batchId]);
      for (final old in oldEntries) {
        await txn.insert('sync_tombstones', {'entity_type':'expenditure_entries','sync_id':old['sync_id'],'deleted_at':now}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.delete('expenditure_entries', where: 'batch_id = ?', whereArgs: [batchId]);
      for (final row in rows) {
        final amount = (row['amount'] as num).toDouble();
        if ((row['description'] as String).trim().isEmpty || amount <= 0) {
          throw ArgumentError('Description and positive amount are required');
        }
        await txn.insert('expenditure_entries', {
          'batch_id': batchId,
          'description': (row['description'] as String).trim(),
          'payee': (row['payee'] as String?)?.trim().isEmpty == true ? null : (row['payee'] as String?)?.trim(),
          'reference': (row['reference'] as String?)?.trim().isEmpty == true ? null : (row['reference'] as String?)?.trim(),
          'amount': amount,
          'created_at': DateTime.now().toIso8601String(),
          'sync_id': _uuid.v4(), 'updated_at': _now(),
        });
      }
    });
    await _markSyncDirty();
    await audit('EXPENDITURE_UPDATED', 'batch=$batchId; rows=${rows.length}');
  }

  Future<void> deleteExpenditureBatch(int batchId) async {
    await _ensureWritable();
    final now = _now();
    await db.transaction((txn) async {
      final batch = await txn.query('expenditure_batches', columns: ['sync_id'], where: 'id=?', whereArgs: [batchId], limit: 1);
      final entries = await txn.query('expenditure_entries', columns: ['sync_id'], where: 'batch_id=?', whereArgs: [batchId]);
      for (final r in entries) await txn.insert('sync_tombstones', {'entity_type':'expenditure_entries','sync_id':r['sync_id'],'deleted_at':now}, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final r in batch) await txn.insert('sync_tombstones', {'entity_type':'expenditure_batches','sync_id':r['sync_id'],'deleted_at':now}, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('expenditure_entries', where: 'batch_id = ?', whereArgs: [batchId]);
      await txn.delete('expenditure_batches', where: 'id = ?', whereArgs: [batchId]);
    });
    await _markSyncDirty();
    await audit('EXPENDITURE_DELETED', 'batch=$batchId');
  }

  Future<Map<String, Object?>> getBalanceOverallStats({DateTime? from, DateTime? to, String? fundName}) async {
    final c = await _contributionTotal(from: from, to: to, fundName: fundName);
    final e = await _expenditureTotal(from: from, to: to, fundName: fundName);
    final income = (c['total'] as num?)?.toDouble() ?? 0;
    final expense = (e['total'] as num?)?.toDouble() ?? 0;
    return {'income': income, 'expenditure': expense, 'balance': income - expense, 'contributionEntries': c['entries'] ?? 0, 'expenditureEntries': e['entries'] ?? 0};
  }

  Future<List<Map<String, Object?>>> getFundBalances({DateTime? from, DateTime? to}) async {
    final wc=<String>[]; final ac=<Object?>[]; final we=<String>[]; final ae=<Object?>[];
    if(from!=null){final v=DateTime(from.year,from.month,from.day).toIso8601String();wc.add('b.date >= ?');ac.add(v);we.add('b.date >= ?');ae.add(v);}
    if(to!=null){final v=DateTime(to.year,to.month,to.day+1).toIso8601String();wc.add('b.date < ?');ac.add(v);we.add('b.date < ?');ae.add(v);}
    final sc=wc.isEmpty?'':'WHERE ${wc.join(' AND ')}'; final se=we.isEmpty?'':'WHERE ${we.join(' AND ')}';
    final rows=await db.rawQuery('''SELECT fund_name, SUM(income) income, SUM(expenditure) expenditure FROM (
      SELECT COALESCE(NULLIF(TRIM(b.fund_name),''),'HAJAWEKWA') fund_name, SUM(x.amount) income, 0 expenditure FROM contribution_batches b JOIN (SELECT batch_id, amount FROM fungu_contributions UNION ALL SELECT batch_id, amount FROM other_contributions) x ON x.batch_id=b.id $sc GROUP BY fund_name
      UNION ALL
      SELECT COALESCE(NULLIF(TRIM(b.fund_name),''),'HAJAWEKWA') fund_name, 0 income, SUM(e.amount) expenditure FROM expenditure_batches b JOIN expenditure_entries e ON e.batch_id=b.id $se GROUP BY fund_name
    ) GROUP BY fund_name ORDER BY fund_name COLLATE NOCASE''',[...ac,...ae]);
    return rows.map((r){final income=(r['income'] as num?)?.toDouble()??0;final exp=(r['expenditure'] as num?)?.toDouble()??0;return {...r,'income':income,'expenditure':exp,'balance':income-exp};}).toList();
  }

  Future<List<Map<String,Object?>>> getBalanceExpenditureByCategory({DateTime? from, DateTime? to, String? fundName}) async {
    final w=<String>[]; final a=<Object?>[]; if(from!=null){w.add('b.date >= ?');a.add(DateTime(from.year,from.month,from.day).toIso8601String());} if(to!=null){w.add('b.date < ?');a.add(DateTime(to.year,to.month,to.day+1).toIso8601String());} if(fundName!=null&&fundName.trim().isNotEmpty){w.add('b.fund_name = ?');a.add(fundName.trim());} final ws=w.isEmpty?'':'WHERE ${w.join(' AND ')}';
    return db.rawQuery('SELECT b.category category, COALESCE(SUM(e.amount),0) total FROM expenditure_batches b JOIN expenditure_entries e ON e.batch_id=b.id $ws GROUP BY b.category ORDER BY total DESC',a);
  }

  Future<List<String>> getBalanceFundNames() async {
    final rows=await db.rawQuery("SELECT fund_name FROM (SELECT DISTINCT TRIM(fund_name) fund_name FROM contribution_batches WHERE fund_name IS NOT NULL AND TRIM(fund_name)<>'' UNION SELECT DISTINCT TRIM(fund_name) fund_name FROM expenditure_batches WHERE fund_name IS NOT NULL AND TRIM(fund_name)<>'') ORDER BY fund_name COLLATE NOCASE");
    return rows.map((r)=>'${r['fund_name']}'.trim()).where((x)=>x.isNotEmpty).toList();
  }


  Future<Map<String, Object?>> getOverallDashboardStats({DateTime? from, DateTime? to, String? fundName}) async {
    final c = await _contributionTotal(from: from, to: to, fundName: fundName);
    final e = await _expenditureTotal(from: from, to: to, fundName: fundName);
    final income = (c['total'] as num?)?.toDouble() ?? 0;
    final expenditure = (e['total'] as num?)?.toDouble() ?? 0;
    return {'income': income, 'expenditure': expenditure, 'balance': income - expenditure, 'contributionEntries': c['entries'] ?? 0, 'expenditureEntries': e['entries'] ?? 0};
  }

  Future<List<Map<String, Object?>>> getOverallContributionBreakdown({DateTime? from, DateTime? to, String? fundName}) async {
    final w = <String>[]; final a = <Object?>[];
    if (from != null) { w.add('b.date >= ?'); a.add(DateTime(from.year, from.month, from.day).toIso8601String()); }
    if (to != null) { w.add('b.date < ?'); a.add(DateTime(to.year, to.month, to.day + 1).toIso8601String()); }
    if (fundName != null && fundName.trim().isNotEmpty) { w.add('b.fund_name = ?'); a.add(fundName.trim()); }
    final ws = w.isEmpty ? '' : 'WHERE ${w.join(' AND ')}';
    return db.rawQuery("""
      SELECT type, COALESCE(SUM(amount),0) total, COUNT(*) entries
      FROM (
        SELECT b.id, b.type, b.fund_name, f.amount FROM contribution_batches b JOIN fungu_contributions f ON f.batch_id=b.id $ws
        UNION ALL
        SELECT b.id, b.type, b.fund_name, o.amount FROM contribution_batches b JOIN other_contributions o ON o.batch_id=b.id $ws
      ) GROUP BY type ORDER BY total DESC
    """, [...a, ...a]);
  }

  Future<List<Map<String, Object?>>> getOverallFundBreakdown({DateTime? from, DateTime? to, String? fundName}) async {
    final wc=<String>[]; final ac=<Object?>[]; final we=<String>[]; final ae=<Object?>[];
    if(from!=null){final v=DateTime(from.year,from.month,from.day).toIso8601String();wc.add('b.date >= ?');ac.add(v);we.add('b.date >= ?');ae.add(v);}
    if(to!=null){final v=DateTime(to.year,to.month,to.day+1).toIso8601String();wc.add('b.date < ?');ac.add(v);we.add('b.date < ?');ae.add(v);}
    if(fundName!=null&&fundName.trim().isNotEmpty){wc.add('b.fund_name = ?');ac.add(fundName.trim());we.add('b.fund_name = ?');ae.add(fundName.trim());}
    final sc=wc.isEmpty?'':'WHERE ${wc.join(' AND ')}'; final se=we.isEmpty?'':'WHERE ${we.join(' AND ')}';
    final rows=await db.rawQuery("""SELECT fund_name, SUM(income) income, SUM(expenditure) expenditure FROM (
      SELECT COALESCE(NULLIF(TRIM(b.fund_name),''),'HAJAWEKWA') fund_name, SUM(x.amount) income, 0 expenditure FROM contribution_batches b JOIN (SELECT batch_id, amount FROM fungu_contributions UNION ALL SELECT batch_id, amount FROM other_contributions) x ON x.batch_id=b.id $sc GROUP BY fund_name
      UNION ALL
      SELECT COALESCE(NULLIF(TRIM(b.fund_name),''),'HAJAWEKWA') fund_name, 0 income, SUM(e.amount) expenditure FROM expenditure_batches b JOIN expenditure_entries e ON e.batch_id=b.id $se GROUP BY fund_name
    ) GROUP BY fund_name ORDER BY (income + expenditure) DESC, fund_name COLLATE NOCASE""",[...ac,...ae]);
    return rows.map((r){final income=(r['income'] as num?)?.toDouble()??0;final exp=(r['expenditure'] as num?)?.toDouble()??0;return {...r,'income':income,'expenditure':exp,'balance':income-exp};}).toList();
  }

  Future<List<Map<String, Object?>>> getOverallDailyTrend({DateTime? from, DateTime? to, String? fundName}) async {
    final wc=<String>[]; final ac=<Object?>[]; final we=<String>[]; final ae=<Object?>[];
    if(from!=null){final v=DateTime(from.year,from.month,from.day).toIso8601String();wc.add('b.date >= ?');ac.add(v);we.add('b.date >= ?');ae.add(v);}
    if(to!=null){final v=DateTime(to.year,to.month,to.day+1).toIso8601String();wc.add('b.date < ?');ac.add(v);we.add('b.date < ?');ae.add(v);}
    if(fundName!=null&&fundName.trim().isNotEmpty){wc.add('b.fund_name = ?');ac.add(fundName.trim());we.add('b.fund_name = ?');ae.add(fundName.trim());}
    final sc=wc.isEmpty?'':'WHERE ${wc.join(' AND ')}'; final se=we.isEmpty?'':'WHERE ${we.join(' AND ')}';
    final rows=await db.rawQuery("""SELECT day, SUM(income) income, SUM(expenditure) expenditure FROM (
      SELECT substr(b.date,1,10) day, SUM(x.amount) income, 0 expenditure FROM contribution_batches b JOIN (SELECT batch_id, amount FROM fungu_contributions UNION ALL SELECT batch_id, amount FROM other_contributions) x ON x.batch_id=b.id $sc GROUP BY day
      UNION ALL
      SELECT substr(b.date,1,10) day, 0 income, SUM(e.amount) expenditure FROM expenditure_batches b JOIN expenditure_entries e ON e.batch_id=b.id $se GROUP BY day
    ) GROUP BY day ORDER BY day ASC""",[...ac,...ae]);
    return rows.map((r){final income=(r['income'] as num?)?.toDouble()??0;final exp=(r['expenditure'] as num?)?.toDouble()??0;return {...r,'income':income,'expenditure':exp,'balance':income-exp};}).toList();
  }

  Future<List<Map<String, Object?>>> getOverallExpenditureBreakdown({DateTime? from, DateTime? to, String? fundName}) async {
    return getBalanceExpenditureByCategory(from: from, to: to, fundName: fundName);
  }

  Future<Map<String,Object?>> _contributionTotal({DateTime? from, DateTime? to, String? fundName}) async {
    final w=<String>[]; final a=<Object?>[]; if(from!=null){w.add('b.date >= ?');a.add(DateTime(from.year,from.month,from.day).toIso8601String());} if(to!=null){w.add('b.date < ?');a.add(DateTime(to.year,to.month,to.day+1).toIso8601String());} if(fundName!=null&&fundName.trim().isNotEmpty){w.add('b.fund_name = ?');a.add(fundName.trim());} final ws=w.isEmpty?'':'WHERE ${w.join(' AND ')}';
    final r=await db.rawQuery('SELECT COUNT(*) entries, COALESCE(SUM(amount),0) total FROM (SELECT b.id,x.amount FROM contribution_batches b JOIN fungu_contributions x ON x.batch_id=b.id $ws UNION ALL SELECT b.id,x.amount FROM contribution_batches b JOIN other_contributions x ON x.batch_id=b.id $ws)',[...a,...a]); return r.first;
  }

  Future<Map<String,Object?>> _expenditureTotal({DateTime? from, DateTime? to, String? fundName}) async {
    final w=<String>[]; final a=<Object?>[]; if(from!=null){w.add('b.date >= ?');a.add(DateTime(from.year,from.month,from.day).toIso8601String());} if(to!=null){w.add('b.date < ?');a.add(DateTime(to.year,to.month,to.day+1).toIso8601String());} if(fundName!=null&&fundName.trim().isNotEmpty){w.add('b.fund_name = ?');a.add(fundName.trim());} final ws=w.isEmpty?'':'WHERE ${w.join(' AND ')}';
    final r=await db.rawQuery('SELECT COUNT(e.id) entries, COALESCE(SUM(e.amount),0) total FROM expenditure_batches b JOIN expenditure_entries e ON e.batch_id=b.id $ws',a); return r.first;
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
    await _ensureWritable();
    final id = await db.insert('contribution_batches', {
      'date': date,
      'type': type,
      'service': service,
      'title': title,
      'created_at': DateTime.now().toIso8601String(),
      'sync_id': _uuid.v4(), 'updated_at': _now(),
    });
    await _markSyncDirty();
    return id;
  }

  /// Hatua ya 4: inatengeneza namba mpya ya risiti (angalia [ReceiptNo]) na kuthibitisha
  /// kuwa haipo kwenye michango iliyohifadhiwa wala kwenye [reserved] (namba
  /// zilizotengenezwa ndani ya batch hii hii). Inatupa kosa baada ya majaribio 50,
  /// jambo ambalo linafuta batch nzima (transaction rollback) badala ya kuhifadhi nusu.
  Future<String> _newReceiptNo(
    DatabaseExecutor ex, {
    required DateTime at,
    required String contributionName,
    required String number,
    required Set<String> reserved,
  }) async {
    for (var attempt = 0; attempt < 50; attempt++) {
      final candidate = ReceiptNo.build(at: at, contributionName: contributionName, number: number);
      if (reserved.contains(candidate)) continue;
      final used = await ex.rawQuery(
        'SELECT 1 FROM fungu_contributions WHERE receipt_no = ? '
        'UNION ALL SELECT 1 FROM other_contributions WHERE receipt_no = ? LIMIT 1',
        [candidate, candidate],
      );
      if (used.isEmpty) {
        reserved.add(candidate);
        return candidate;
      }
    }
    throw StateError('receipt_generation_failed');
  }

  Future<int> saveFunguBatch({
    required String date,
    required int service,
    required String title,
    required String fundName,
    required List<Map<String, Object?>> rows,
  }) async {
    await _ensureWritable();
    final batchId = await db.transaction<int>((txn) async {
      final batchId = await txn.insert('contribution_batches', {
        'date': date,
        'type': 'FUNGU',
        'service': service,
        'title': title,
        'fund_name': fundName.trim().isEmpty ? null : fundName.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'sync_id': _uuid.v4(), 'updated_at': _now(),
      });
      final issuedAt = DateTime.now();
      final reserved = <String>{};
      for (final row in rows) {
        // Namba ya risiti inatengenezwa hapa na kurudishwa kwenye [row] ('receiptNo').
        final receiptNo = await _newReceiptNo(
          txn,
          at: issuedAt,
          contributionName: 'FUNGU',
          number: '${row['envelopeNo'] ?? ''}',
          reserved: reserved,
        );
        row['receiptNo'] = receiptNo;
        await txn.insert('fungu_contributions', {
          'batch_id': batchId,
          'envelope_no': row['envelopeNo'],
          'donor_name': row['donorName'],
          'sex': row['sex'],
          'contact': row['contact'],
          'amount': row['amount'],
          'receipt_no': receiptNo,
          'created_at': DateTime.now().toIso8601String(),
          'sync_id': _uuid.v4(), 'updated_at': _now(),
        });
      }
      return batchId;
    });
    await _markSyncDirty();
    return batchId;
  }

  Future<int> saveOtherBatch({
    required String date,
    required int service,
    required String title,
    required String fundName,
    required List<Map<String, Object?>> rows,
  }) async {
    await _ensureWritable();
    final batchId = await db.transaction<int>((txn) async {
      final batchId = await txn.insert('contribution_batches', {
        'date': date,
        'type': 'OTHER',
        'service': service,
        'title': title,
        'fund_name': fundName.trim().isEmpty ? null : fundName.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'sync_id': _uuid.v4(), 'updated_at': _now(),
      });
      final countRows =
          await txn.rawQuery('SELECT COUNT(*) AS c FROM other_contributions');
      var nextNumber = (countRows.first['c'] as int? ?? 0) + 1;
      final issuedAt = DateTime.now();
      final reserved = <String>{};
      for (final row in rows) {
        final nameNo = 'MCH-${nextNumber.toString().padLeft(5, '0')}';
        nextNumber++;
        // Namba ya risiti inatengenezwa hapa na kurudishwa kwenye [row] ('receiptNo').
        final receiptNo = await _newReceiptNo(
          txn,
          at: issuedAt,
          contributionName: '${row['contributionName'] ?? ''}',
          number: nameNo,
          reserved: reserved,
        );
        row['receiptNo'] = receiptNo;
        await txn.insert('other_contributions', {
          'batch_id': batchId,
          'contribution_name': row['contributionName'],
          'donor_name': row['donorName'],
          'sex': row['sex'],
          'name_no': nameNo,
          'contact': row['contact'],
          'amount': row['amount'],
          'receipt_no': receiptNo,
          'created_at': DateTime.now().toIso8601String(),
          'sync_id': _uuid.v4(), 'updated_at': _now(),
        });
      }
      return batchId;
    });
    await _markSyncDirty();
    return batchId;
  }

  Future<int> addFunguContribution({
    required int batchId,
    required String envelopeNo,
    required String donorName,
    required String contact,
    required double amount,
    required String receiptNo,
  }) async {
    final id = await db.insert('fungu_contributions', {
      'batch_id': batchId,
      'envelope_no': envelopeNo.trim(),
      'donor_name': donorName.trim().isEmpty ? null : donorName.trim(),
      'contact': contact.trim().isEmpty ? null : contact.trim(),
      'amount': amount,
      'receipt_no': receiptNo,
      'created_at': DateTime.now().toIso8601String(),
      'sync_id': _uuid.v4(), 'updated_at': _now(),
    });
    await _markSyncDirty();
    return id;
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
    final id = await db.insert('other_contributions', {
      'batch_id': batchId,
      'contribution_name': contributionName.trim(),
      'donor_name': donorName.trim(),
      'name_no': nameNo,
      'contact': contact.trim().isEmpty ? null : contact.trim(),
      'amount': amount,
      'receipt_no': receiptNo,
      'created_at': DateTime.now().toIso8601String(),
      'sync_id': _uuid.v4(), 'updated_at': _now(),
    });
    await _markSyncDirty();
    return id;
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

  /// Mistari yote ya michango (FUNGU na michango mingine), kuanzia ya zamani zaidi.
  /// Inatumika kujenga jedwali la watoaji kwa miezi na wiki, na ukurasa wa mtoaji.
  Future<List<Map<String, Object?>>> getContributionLedger() async {
    final fungu = await db.rawQuery('''
      SELECT b.date AS date, COALESCE(b.service, 1) AS service,
             f.id AS row_id, f.envelope_no AS id_no, f.donor_name AS donor_name,
             f.contact AS contact, f.sex AS sex,
             CAST(COALESCE(f.amount, 0) AS REAL) AS amount, f.receipt_no AS receipt_no,
             b.fund_name AS fund_name, f.created_at AS created_at
      FROM contribution_batches b
      JOIN fungu_contributions f ON f.batch_id = b.id
      ORDER BY b.date ASC, f.id ASC
    ''');
    final other = await db.rawQuery('''
      SELECT b.date AS date, COALESCE(b.service, 1) AS service,
             o.id AS row_id, o.name_no AS id_no, o.donor_name AS donor_name,
             o.contact AS contact, o.sex AS sex, o.contribution_name AS contribution_name,
             CAST(COALESCE(o.amount, 0) AS REAL) AS amount, o.receipt_no AS receipt_no,
             b.fund_name AS fund_name, o.created_at AS created_at
      FROM contribution_batches b
      JOIN other_contributions o ON o.batch_id = b.id
      ORDER BY b.date ASC, o.id ASC
    ''');
    final out = <Map<String, Object?>>[
      for (final r in fungu) {...r, 'type': 'FUNGU', 'contribution_name': 'FUNGU'},
      for (final r in other) {...r, 'type': 'OTHER'},
    ];
    out.sort((x, y) => '${x['date']}'.compareTo('${y['date']}'));
    return out;
  }

  Future<List<Map<String, Object?>>> getContributionDetailsForDay(String day) async {
    // Maswali mawili tofauti (badala ya UNION ALL) ili Android na Windows zitoe
    // matokeo sawa; kiasi kinalazimishwa kuwa namba (REAL).
    final fungu = await db.rawQuery('''
      SELECT b.id AS batch_id, b.date AS date, 'FUNGU' AS type,
             COALESCE(b.service, 1) AS service, b.title AS title, b.created_at AS created_at,
             f.id AS row_id, f.envelope_no AS envelope_no, f.donor_name AS donor_name,
             f.contact AS contact, CAST(COALESCE(f.amount, 0) AS REAL) AS amount,
             f.receipt_no AS receipt_no, f.sex AS sex
      FROM contribution_batches b
      JOIN fungu_contributions f ON f.batch_id = b.id
      WHERE substr(b.date,1,10) = ?
      ORDER BY b.id ASC, f.id ASC
    ''', [day]);
    final other = await db.rawQuery('''
      SELECT b.id AS batch_id, b.date AS date, 'OTHER' AS type,
             COALESCE(b.service, 1) AS service, b.title AS title, b.created_at AS created_at,
             o.id AS row_id, o.donor_name AS donor_name, o.contact AS contact,
             CAST(COALESCE(o.amount, 0) AS REAL) AS amount, o.receipt_no AS receipt_no,
             o.contribution_name AS contribution_name, o.name_no AS name_no, o.sex AS sex
      FROM contribution_batches b
      JOIN other_contributions o ON o.batch_id = b.id
      WHERE substr(b.date,1,10) = ?
      ORDER BY b.id ASC, o.id ASC
    ''', [day]);
    final out = <Map<String, Object?>>[
      for (final r in fungu) {...r, 'contribution_name': null, 'name_no': null},
      for (final r in other) {...r, 'envelope_no': null},
    ];
    out.sort((x, y) {
      final s = ((x['service'] as num?) ?? 1).compareTo((y['service'] as num?) ?? 1);
      if (s != 0) return s;
      final t = '${x['type']}'.compareTo('${y['type']}');
      if (t != 0) return t;
      final bch = ((x['batch_id'] as num?) ?? 0).compareTo((y['batch_id'] as num?) ?? 0);
      if (bch != 0) return bch;
      return ((x['row_id'] as num?) ?? 0).compareTo((y['row_id'] as num?) ?? 0);
    });
    return out;
  }

  Future<int> updateFunguContribution({required int id, required String envelopeNo, required String donorName, required String contact, required double amount, String? sex}) async {
    await _ensureWritable();
    final count = await db.update('fungu_contributions', {
      'envelope_no': envelopeNo.trim(),
      'donor_name': donorName.trim().isEmpty ? null : donorName.trim(),
      if (sex != null) 'sex': sex,
      'contact': contact.trim().isEmpty ? null : contact.trim(),
      'amount': amount,
      'updated_at': _now(),
    }, where: 'id = ?', whereArgs: [id]);
    await _markSyncDirty();
    await audit('CONTRIBUTION_FUNGU_UPDATED', 'id=$id; amount=$amount');
    return count;
  }

  Future<int> updateOtherContribution({required int id, required String contributionName, required String donorName, required String contact, required double amount, String? sex}) async {
    await _ensureWritable();
    final count = await db.update('other_contributions', {
      'contribution_name': contributionName.trim(),
      'donor_name': donorName.trim(),
      if (sex != null) 'sex': sex,
      'contact': contact.trim().isEmpty ? null : contact.trim(),
      'amount': amount,
      'updated_at': _now(),
    }, where: 'id = ?', whereArgs: [id]);
    await _markSyncDirty();
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

  /// Futa mstari mmoja wa mchango. Ikiwa ulikuwa mstari wa mwisho wa batch,
  /// container ya batch nayo huondolewa ili takwimu za siku zisibaki na batch tupu.
  Future<void> deleteContributionRow({
    required int id,
    required bool isFungu,
  }) async {
    await _ensureWritable();
    final table = isFungu ? 'fungu_contributions' : 'other_contributions';
    final now = _now();
    await db.transaction((txn) async {
      final rows = await txn.query(
        table,
        columns: ['batch_id', 'sync_id'],
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      final batchId = (row['batch_id'] as num).toInt();
      final syncId = '${row['sync_id']}';
      await txn.insert(
        'sync_tombstones',
        {'entity_type': table, 'sync_id': syncId, 'deleted_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(table, where: 'id=?', whereArgs: [id]);

      final remaining = await txn.rawQuery("""
        SELECT
          (SELECT COUNT(*) FROM fungu_contributions WHERE batch_id=?) +
          (SELECT COUNT(*) FROM other_contributions WHERE batch_id=?) AS c
      """, [batchId, batchId]);
      final count = (remaining.first['c'] as num?)?.toInt() ?? 0;
      if (count == 0) {
        final batch = await txn.query(
          'contribution_batches',
          columns: ['sync_id'],
          where: 'id=?',
          whereArgs: [batchId],
          limit: 1,
        );
        for (final b in batch) {
          await txn.insert(
            'sync_tombstones',
            {
              'entity_type': 'contribution_batches',
              'sync_id': b['sync_id'],
              'deleted_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await txn.delete('contribution_batches', where: 'id=?', whereArgs: [batchId]);
      }
    });
    await _markSyncDirty();
    await audit('CONTRIBUTION_DELETED', 'table=$table; id=$id');
  }

  /// Hufuta data zote za biashara (michango + matumizi) bila kugusa PIN,
  /// lugha, settings za app au audit log. Tombstones zinahifadhiwa ili
  /// deletion isambae kwenye vifaa vilivyounganishwa wakati wa sync.
  Future<Map<String, int>> deleteAllBusinessData() async {
    await _ensureWritable();
    final now = _now();
    final counts = <String, int>{};
    await db.transaction((txn) async {
      for (final table in const [
        'fungu_contributions',
        'other_contributions',
        'expenditure_entries',
        'contribution_batches',
        'expenditure_batches',
      ]) {
        final rows = await txn.query(table, columns: ['sync_id']);
        counts[table] = rows.length;
        for (final row in rows) {
          await txn.insert(
            'sync_tombstones',
            {
              'entity_type': table,
              'sync_id': row['sync_id'],
              'deleted_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      await txn.delete('fungu_contributions');
      await txn.delete('other_contributions');
      await txn.delete('expenditure_entries');
      await txn.delete('contribution_batches');
      await txn.delete('expenditure_batches');
    });
    await _markSyncDirty();
    await audit(
      'ALL_BUSINESS_DATA_DELETED',
      'fungu=${counts['fungu_contributions'] ?? 0}; '
          'other=${counts['other_contributions'] ?? 0}; '
          'expense_rows=${counts['expenditure_entries'] ?? 0}; '
          'contribution_batches=${counts['contribution_batches'] ?? 0}; '
          'expense_batches=${counts['expenditure_batches'] ?? 0}',
    );
    return counts;
  }

  Future<Map<String, int>> getBusinessDataCounts() async {
    final result = <String, int>{};
    for (final table in const [
      'fungu_contributions',
      'other_contributions',
      'expenditure_entries',
      'contribution_batches',
      'expenditure_batches',
    ]) {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      result[table] = (rows.first['c'] as num?)?.toInt() ?? 0;
    }
    return result;
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
