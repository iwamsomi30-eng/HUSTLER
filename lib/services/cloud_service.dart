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

/// Secure central sync. Local SQLite remains the source used by the UI while
/// Supabase provides the shared account/tenant and durable cloud copy.
class CloudService {
  static SupabaseClient get client => Supabase.instance.client;

  static bool get available => CloudConfig.configured;
  static User? get user => available ? client.auth.currentUser : null;
  static Session? get session => available ? client.auth.currentSession : null;

  static Future<void> initialize() async {
    if (!CloudConfig.configured) return;
    await Supabase.initialize(url: CloudConfig.url, publishableKey: CloudConfig.publishableKey);
  }

  static Future<AuthResponse> signIn({required String email, required String password}) async {
    return client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  static Future<AuthResponse> signUp({required String email, required String password}) async {
    return client.auth.signUp(email: email.trim(), password: password);
  }

  static Future<void> signOut() async => client.auth.signOut();

  static Future<String?> currentChurchId() async {
    final uid = user?.id;
    if (uid == null) return null;
    final row = await client.from('church_members').select('church_id').eq('user_id', uid).eq('status', 'active').limit(1).maybeSingle();
    return row?['church_id'] as String?;
  }

  static Future<String?> currentRole() async {
    final uid = user?.id;
    if (uid == null) return null;
    final church = await currentChurchId();
    if (church == null) return null;
    final row = await client.from('church_members').select('role').eq('church_id', church).eq('user_id', uid).eq('status','active').maybeSingle();
    final role = row?['role'] as String?;
    if (role != null) await AppDb.instance.setSetting('cloud_role', role);
    return role;
  }

  static bool _syncing = false;

  static Future<CloudSyncResult> sync() async {
    if (_syncing) return const CloudSyncResult(uploaded: 0, downloaded: 0, conflicts: 0);
    _syncing = true;
    try {
    final uid = user?.id;
    if (uid == null) throw StateError('CLOUD_LOGIN_REQUIRED');
    final churchId = await currentChurchId();
    if (churchId == null) throw StateError('NO_CHURCH_ACCESS');
    final role = await currentRole();
    if (role == null) throw StateError('NO_CHURCH_ACCESS');

    final device = await SyncService.deviceId();
    final last = await AppDb.instance.getSetting('cloud_last_sync_at');
    final rows = await AppDb.instance.syncRows(since: last == null ? null : DateTime.tryParse(last));
    int uploaded = 0;
    int conflicts = 0;

    // Upload local state. The server key is tenant + entity type + sync_id.
    for (final row in rows) {
      final entityType = row['entity_type'] as String;
      final syncId = row['sync_id'] as String;
      final payload = Map<String, dynamic>.from(row['payload'] as Map);
      final updatedAt = row['updated_at'] as String;
      try {
        final accepted = await client.rpc('upsert_sync_record', params: {
          'p_church_id': churchId,
          'p_entity_type': entityType,
          'p_sync_id': syncId,
          'p_payload': payload,
          'p_updated_at': updatedAt,
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
    const order = {'contribution_batches':0,'expenditure_batches':1,'fungu_contributions':2,'other_contributions':3,'expenditure_entries':4};
    remote.sort((a,b) => ((order['${a['entity_type']}'] ?? 9) as int).compareTo((order['${b['entity_type']}'] ?? 9) as int));
    int downloaded = 0;
    for (final raw in remote) {
      final r = Map<String, dynamic>.from(raw);
      final entityType = r['entity_type'] as String;
      final syncId = r['sync_id'] as String;
      final updatedAt = r['updated_at'] as String;
      final deleted = r['deleted'] == true;
      final payload = Map<String, dynamic>.from(r['payload'] as Map? ?? {});
      final applied = await AppDb.instance.applyRemoteSyncRow(
        entityType: entityType,
        syncId: syncId,
        updatedAt: updatedAt,
        deleted: deleted,
        payload: payload,
      );
      if (applied) downloaded++;
    }
    await AppDb.instance.setSetting('cloud_last_sync_at', DateTime.now().toUtc().toIso8601String());
    await AppDb.instance.setSetting('cloud_last_sync_status', 'ok');
    await AppDb.instance.audit('CLOUD_SYNC', 'uploaded=$uploaded; downloaded=$downloaded; conflicts=$conflicts');
    return CloudSyncResult(uploaded: uploaded, downloaded: downloaded, conflicts: conflicts);
    } finally {
      _syncing = false;
    }
  }
}
