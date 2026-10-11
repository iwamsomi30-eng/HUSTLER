import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/cloud_config.dart';
import '../core/db.dart';
import 'sync_service.dart';

class CloudSyncResult {
  final int uploaded;
  final int downloaded;
  final int conflicts;
  const CloudSyncResult({required this.uploaded, required this.downloaded, required this.conflicts});
}

class CloudChurch {
  final String id;
  final String name;
  final String role;
  const CloudChurch({required this.id, required this.name, required this.role});
}

/// Code ya muda ya kuunganisha kifaa kipya (QR + OTP).
class LinkCode {
  final String id;
  final String code;   // OTP ya tarakimu 8
  final String token;  // siri ndefu ndani ya QR
  final DateTime expiresAt;
  const LinkCode({required this.id, required this.code, required this.token, required this.expiresAt});

  static const qrPrefix = 'HUSTLER-LINK:1:';
  String get qrPayload => '$qrPrefix$token';
  String get codeDisplay => code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;
}

/// Kosa la kuunganisha: INVALID (code si sahihi/imeisha), TOO_MANY (majaribio mengi).
class LinkException implements Exception {
  final String code;
  const LinkException(this.code);
  @override
  String toString() => 'LinkException($code)';
}

/// Secure central sync. Vifaa VINAUNGANISHWA kwa QR au OTP tu (hakuna email/password).
/// Kila kifaa kinapata session ya "anonymous" ya Supabase; ruhusa ya kuona data
/// inatolewa na seva pale tu QR/OTP halali inapotumika (redeem_pairing_code).
class CloudService {
  static SupabaseClient get client => Supabase.instance.client;

  static bool get available => CloudConfig.configured;
  static User? get user => available ? client.auth.currentUser : null;
  static Session? get session => available ? client.auth.currentSession : null;

  static const _kChurchId = 'cloud_church_id';
  static const _kChurchName = 'cloud_church_name';
  static const _kRole = 'cloud_role';
  static const _kLastSync = 'cloud_last_sync_at';

  static Future<void> initialize() async {
    if (!CloudConfig.configured) return;
    await Supabase.initialize(url: CloudConfig.url, publishableKey: CloudConfig.publishableKey);
    startAutoSync();
  }

  // ---------------------------------------------------------------- hali ya kifaa

  static Future<String?> _get(String key) async {
    final v = await AppDb.instance.getSetting(key);
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Kanisa ambalo kifaa hiki kimeunganishwa nalo (kutoka cache ya ndani, inafanya kazi offline).
  static Future<CloudChurch?> cachedChurch() async {
    if (!available || user == null) return null;
    final id = await _get(_kChurchId);
    if (id == null) return null;
    final cachedRole = await _get(_kRole) ?? 'editor';
    return CloudChurch(id: id, name: await _get(_kChurchName) ?? '', role: cachedRole == 'viewer' ? 'editor' : cachedRole);
  }

  static Future<void> _saveChurch(CloudChurch c, {bool resetSyncCursor = false}) async {
    final db = AppDb.instance;
    await db.setSetting(_kChurchId, c.id);
    await db.setSetting(_kChurchName, c.name);
    await db.setSetting(_kRole, c.role);
    if (resetSyncCursor) await db.setSetting(_kLastSync, '');
  }

  static Future<void> _clearChurch() async {
    final db = AppDb.instance;
    await db.setSetting(_kChurchId, '');
    await db.setSetting(_kChurchName, '');
    await db.setSetting(_kRole, '');
    await db.setSetting(_kLastSync, '');
  }

  /// Inahakiki kwenye seva kuwa kifaa bado kina access. Inarudisha null kama access imeondolewa.
  /// Inatupa exception tu kukiwa na tatizo la mtandao.
  static Future<CloudChurch?> refreshChurch() async {
    final uid = user?.id;
    if (uid == null) return null;
    final row = await client
        .from('church_members')
        .select('church_id, role')
        .eq('user_id', uid)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    if (row == null) {
      await _clearChurch();
      return null;
    }
    final churchId = row['church_id'] as String;
    final c = await client.from('churches').select('name').eq('id', churchId).maybeSingle();
    final church = CloudChurch(
      id: churchId,
      name: (c?['name'] as String?) ?? await _get(_kChurchName) ?? '',
      role: (row['role'] as String) == 'viewer' ? 'editor' : row['role'] as String,
    );
    await _saveChurch(church);
    return church;
  }

  // ---------------------------------------------------------------- kuanzisha / kuunganisha

  static Future<void> _ensureSession() async {
    if (!available) throw StateError('CLOUD_NOT_CONFIGURED');
    if (client.auth.currentSession == null) await client.auth.signInAnonymously();
  }

  static String defaultDeviceName() {
    if (kIsWeb) return 'Web';
    final n = defaultTargetPlatform.name;
    return n.isEmpty ? 'Kifaa' : '${n[0].toUpperCase()}${n.substring(1)}';
  }

  /// Kifaa cha KWANZA: kinaunda kanisa jipya na kinakuwa admin.
  static Future<CloudChurch> createChurch(String name, {String? deviceName}) async {
    await _ensureSession();
    final res = await client.rpc('create_church', params: {
      'p_name': name.trim(),
      'p_device_id': await SyncService.deviceId(),
      'p_device_name': deviceName ?? defaultDeviceName(),
    });
    final m = Map<String, dynamic>.from(res as Map);
    final church = CloudChurch(id: m['church_id'] as String, name: m['church_name'] as String, role: m['role'] as String);
    await _saveChurch(church, resetSyncCursor: true);
    return church;
  }

  /// Kifaa KIPYA: kinatumia siri iliyo kwenye QR (token) au OTP ya tarakimu 8.
  static Future<CloudChurch> redeemLink(String secret, {String? deviceName}) async {
    await _ensureSession();
    var s = secret.trim();
    if (s.startsWith(LinkCode.qrPrefix)) s = s.substring(LinkCode.qrPrefix.length);
    final res = await client.rpc('redeem_pairing_code', params: {
      'p_secret': s,
      'p_device_id': await SyncService.deviceId(),
      'p_device_name': (deviceName == null || deviceName.trim().isEmpty) ? defaultDeviceName() : deviceName.trim(),
    });
    final m = Map<String, dynamic>.from(res as Map);
    if (m['ok'] != true) throw LinkException('${m['error'] ?? 'INVALID'}');
    final church = CloudChurch(id: m['church_id'] as String, name: (m['church_name'] as String?) ?? '', role: m['role'] as String);
    // Kifaa kipya kinapakua data zote tangu mwanzo.
    await _saveChurch(church, resetSyncCursor: true);
    return church;
  }

  // ---------------------------------------------------------------- admin: kuunganisha vifaa vingine

  static Future<LinkCode> createLinkCode({required String role}) async {
    final church = await cachedChurch();
    if (church == null) throw StateError('NO_CHURCH_ACCESS');
    final res = await client.rpc('create_pairing_code', params: {'p_church_id': church.id, 'p_role': 'editor'});
    final m = Map<String, dynamic>.from(res as Map);
    return LinkCode(
      id: m['id'] as String,
      code: m['code'] as String,
      token: m['token'] as String,
      expiresAt: DateTime.parse(m['expires_at'] as String).toLocal(),
    );
  }

  /// Jina la kifaa kilichotumia code hii, au null kama bado.
  static Future<String?> linkCodeUsedBy(String id) async {
    final row = await client.from('pairing_codes').select('used_at, used_device_name').eq('id', id).maybeSingle();
    if (row == null || row['used_at'] == null) return null;
    return (row['used_device_name'] as String?) ?? '';
  }

  static Future<List<Map<String, dynamic>>> listDevices() async {
    final church = await cachedChurch();
    if (church == null) return [];
    final devices = await client
        .from('device_registry')
        .select('device_id, device_name, user_id, last_seen_at, revoked_at')
        .eq('church_id', church.id)
        .order('last_seen_at', ascending: false);
    final roles = <String, String>{};
    try {
      final members = await client.from('church_members').select('user_id, role, status').eq('church_id', church.id);
      for (final m in members) {
        final memberRole = '${m['role']}';
        roles['${m['user_id']}'] = m['status'] == 'active' ? (memberRole == 'viewer' ? 'editor' : memberRole) : 'disabled';
      }
    } catch (_) {}
    return [
      for (final d in devices) {...Map<String, dynamic>.from(d), 'role': roles['${d['user_id']}']}
    ];
  }

  static Future<void> revokeDevice(String deviceId) async {
    final church = await cachedChurch();
    if (church == null) throw StateError('NO_CHURCH_ACCESS');
    await client.rpc('revoke_device', params: {'p_church_id': church.id, 'p_device_id': deviceId});
  }

  /// Kutenganisha kifaa hiki. Data ya ndani inabaki; ili kuunganisha tena unahitaji QR/OTP mpya.
  static Future<void> disconnect() async {
    await disposeSync();
    try {
      await client.auth.signOut();
    } catch (_) {}
    await _clearChurch();
  }

  // ---------------------------------------------------------------- sync

  static bool _syncing = false;
  static Timer? _autoSyncTimer;
  static Timer? _realtimeKick;
  static dynamic _realtimeChannel;
  static String? _realtimeChurchId;

  static void startAutoSync() {
    _autoSyncTimer ??= Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!available || user == null) return;
      try {
        final dirty = await AppDb.instance.getSetting('cloud_sync_dirty');
        if (dirty != null && dirty.isNotEmpty) await sync();
      } catch (_) {}
    });
  }

  static Future<void> _ensureRealtime(String churchId) async {
    if (_realtimeChurchId == churchId && _realtimeChannel != null) return;
    try {
      if (_realtimeChannel != null) {
        await _realtimeChannel.unsubscribe();
      }
    } catch (_) {}
    _realtimeChannel = null;
    _realtimeChurchId = churchId;

    final channel = client.channel('church-sync-$churchId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sync_records',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'church_id',
        value: churchId,
      ),
      callback: (_) {
        _realtimeKick?.cancel();
        _realtimeKick = Timer(const Duration(milliseconds: 450), () async {
          if (_syncing || user == null) return;
          try { await sync(); } catch (_) {}
        });
      },
    );
    _realtimeChannel = channel;
    await channel.subscribe();
  }

  static Future<void> disposeSync() async {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _realtimeKick?.cancel();
    _realtimeKick = null;
    try { await _realtimeChannel?.unsubscribe(); } catch (_) {}
    _realtimeChannel = null;
    _realtimeChurchId = null;
  }

  static Future<CloudSyncResult> sync() async {
    if (_syncing) return const CloudSyncResult(uploaded: 0, downloaded: 0, conflicts: 0);
    _syncing = true;
    try {
      if (user == null) throw StateError('CLOUD_LOGIN_REQUIRED');
      final church = await refreshChurch();
      if (church == null) throw StateError('NO_CHURCH_ACCESS');
      final churchId = church.id;
      await _ensureRealtime(churchId);

      final device = await SyncService.deviceId();
      final dirtyAtStart = await AppDb.instance.getSetting('cloud_sync_dirty');
      try {
        await client.rpc('touch_device', params: {
          'p_church_id': churchId,
          'p_device_id': device,
          'p_device_name': defaultDeviceName(),
        });
      } catch (_) {}

      final lastRaw = await AppDb.instance.getSetting(_kLastSync);
      final last = (lastRaw == null || lastRaw.isEmpty) ? null : lastRaw;
      int uploaded = 0;
      int conflicts = 0;

      // Kila kifaa kilicholinkiwa ni peer kamili: kinatuma na kupokea data.
      final rows = await AppDb.instance.syncRows(since: last == null ? null : DateTime.tryParse(last));
      for (final row in rows) {
        try {
          final accepted = await client.rpc('upsert_sync_record', params: {
            'p_church_id': churchId,
            'p_entity_type': row['entity_type'] as String,
            'p_sync_id': row['sync_id'] as String,
            'p_payload': Map<String, dynamic>.from(row['payload'] as Map),
            'p_updated_at': row['updated_at'] as String,
            'p_deleted': row['deleted'] == true,
            'p_device_id': device,
          });
          if (accepted == true) uploaded++;
        } catch (_) {
          conflicts++;
        }
      }

      var q = client.from('sync_records').select();
      q = q.eq('church_id', churchId);
      if (last != null) q = q.gt('updated_at', last);
      final remote = await q.order('updated_at', ascending: true);
      const order = {'contribution_batches': 0, 'expenditure_batches': 1, 'fungu_contributions': 2, 'other_contributions': 3, 'expenditure_entries': 4};
      remote.sort((a, b) => ((order['${a['entity_type']}'] ?? 9)).compareTo((order['${b['entity_type']}'] ?? 9)));
      int downloaded = 0;
      for (final raw in remote) {
        final r = Map<String, dynamic>.from(raw);
        final applied = await AppDb.instance.applyRemoteSyncRow(
          entityType: r['entity_type'] as String,
          syncId: r['sync_id'] as String,
          updatedAt: r['updated_at'] as String,
          deleted: r['deleted'] == true,
          payload: Map<String, dynamic>.from(r['payload'] as Map? ?? {}),
        );
        if (applied) downloaded++;
      }
      final remoteMax = remote.isEmpty
          ? null
          : remote.map((r) => DateTime.tryParse('${r['updated_at']}'))
              .whereType<DateTime>()
              .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      final cursor = remoteMax ?? DateTime.now().toUtc();
      await AppDb.instance.setSetting(_kLastSync, cursor.toUtc().toIso8601String());
      if (dirtyAtStart == await AppDb.instance.getSetting('cloud_sync_dirty')) {
        await AppDb.instance.setSetting('cloud_sync_dirty', '');
      }
      await AppDb.instance.setSetting('cloud_last_sync_status', 'ok');
      await AppDb.instance.audit('CLOUD_SYNC', 'uploaded=$uploaded; downloaded=$downloaded; conflicts=$conflicts');
      return CloudSyncResult(uploaded: uploaded, downloaded: downloaded, conflicts: conflicts);
    } finally {
      _syncing = false;
    }
  }
}
