import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import '../core/cloud_config.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/cloud_service.dart';
import '../services/sync_service.dart';
import 'link_code_dialog.dart';
import 'link_device_page.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});
  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final _churchName = TextEditingController();
  bool busy = false;
  bool loading = true;
  bool ok = false;
  String? status;
  String? device;
  CloudChurch? church;
  List<Map<String, dynamic>> devices = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _churchName.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final d = await SyncService.deviceId();
    CloudChurch? c = await CloudService.cachedChurch();
    if (mounted) setState(() { device = d; church = c; loading = false; });
    if (!CloudService.available || CloudService.user == null) return;
    try {
      final had = c != null;
      c = await CloudService.refreshChurch();
      if (had && c == null && mounted) setState(() { ok = false; status = tr('link_access_removed'); });
    } catch (_) {/* offline: tumia cache */}
    if (!mounted) return;
    setState(() => church = c);
    if (c?.role == 'admin') _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final l = await CloudService.listDevices();
      if (mounted) setState(() => devices = l);
    } catch (_) {}
  }

  String _err(Object e) {
    if (e is AuthException) return tr('cloud_anon_disabled');
    final s = e.toString();
    if (s.contains('NO_CHURCH_ACCESS')) return tr('link_access_removed');
    if (s.contains('CLOUD_NOT_CONFIGURED')) return CloudConfig.missingMessage() ?? '';
    return tr('cloud_sync_failed');
  }

  Future<void> _create() async {
    if (!CloudService.available) { setState(() { ok = false; status = CloudConfig.missingMessage(); }); return; }
    if (_churchName.text.trim().length < 2) { setState(() { ok = false; status = tr('link_name_short'); }); return; }
    setState(() { busy = true; status = null; ok = false; });
    try {
      await CloudService.createChurch(_churchName.text);
      final r = await CloudService.sync(); // pakia data zilizopo kwenye kifaa hiki
      if (mounted) setState(() { ok = true; status = '${tr('cloud_sync_done')} ${tr('cloud_uploaded')} ${r.uploaded}'; });
      await _refresh();
    } catch (e) {
      if (mounted) setState(() { ok = false; status = e is AuthException ? tr('cloud_anon_disabled') : tr('link_create_failed'); });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _join() async {
    if (!CloudService.available) { setState(() { ok = false; status = CloudConfig.missingMessage(); }); return; }
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LinkDevicePage()));
    if (r == true && mounted) {
      setState(() { ok = true; status = tr('link_done'); });
      await _refresh();
    }
  }

  Future<void> _showCode() async {
    await showDialog<bool>(context: context, builder: (_) => const LinkCodeDialog());
    _loadDevices();
  }

  Future<void> _sync() async {
    setState(() { busy = true; status = null; ok = false; });
    try {
      final r = await CloudService.sync();
      if (mounted) setState(() { ok = true; status = '${tr('cloud_sync_done')} ${tr('cloud_uploaded')} ${r.uploaded} • ${tr('cloud_downloaded')} ${r.downloaded} • ${tr('cloud_conflicts')} ${r.conflicts}'; });
    } catch (e) {
      if (mounted) setState(() { status = _err(e); });
      if (e.toString().contains('NO_CHURCH_ACCESS')) await _refresh();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('link_yes'))),
          ],
        ),
      ) ?? false;

  Future<void> _disconnect() async {
    if (!await _confirm(tr('link_disconnect_q'))) return;
    await CloudService.disconnect();
    if (mounted) setState(() { church = null; devices = []; ok = true; status = tr('link_disconnected'); });
  }

  Future<void> _revoke(String deviceId) async {
    if (!await _confirm(tr('link_revoke_q'))) return;
    try {
      await CloudService.revokeDevice(deviceId);
    } catch (_) {
      if (mounted) setState(() { ok = false; status = tr('cloud_network_error'); });
    }
    _loadDevices();
  }

  // ------------------------------------------------------------------ UI

  Widget _card(List<Widget> children) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      );

  Widget _head(IconData icon, String title, String sub) => Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.teal.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: C.teal, size: 28)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: C.muted)),
        ])),
      ]);

  Widget _row(IconData i, String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(i, size: 20, color: C.muted),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(a, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(b)),
        ]),
      );

  String _roleLabel(String? r) => tr('role_${r ?? 'viewer'}');

  String _fmt(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '-';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
  }

  List<Widget> _unlinked() => [
        _card([
          _head(Icons.link, tr('link_join_title'), tr('link_join_sub')),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: busy ? null : _join, icon: const Icon(Icons.qr_code_scanner), label: Text(tr('link_join_btn'))),
        ]),
        const SizedBox(height: 16),
        _card([
          _head(Icons.church_outlined, tr('link_create_title'), tr('link_create_sub')),
          const SizedBox(height: 16),
          TextField(controller: _churchName, enabled: !busy, maxLength: 80, decoration: InputDecoration(labelText: tr('link_church_name'), prefixIcon: const Icon(Icons.church), counterText: '')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : _create,
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_outlined),
            label: Text(tr('link_create_btn')),
          ),
        ]),
      ];

  List<Widget> _linked(CloudChurch c) => [
        _card([
          _head(Icons.cloud_sync_rounded, tr('cloud_sync_title'), tr('cloud_sync_sub')),
          const SizedBox(height: 20),
          _row(Icons.church_outlined, tr('link_church'), c.name),
          _row(Icons.verified_user_outlined, tr('link_role'), _roleLabel(c.role)),
          _row(Icons.devices_outlined, tr('sync_device_id'), device ?? '…'),
          if (c.role == 'viewer') Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('link_viewer_note'), style: const TextStyle(color: C.muted))),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            ElevatedButton.icon(
              onPressed: busy ? null : _sync,
              icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
              label: Text(tr('cloud_sync_now')),
            ),
            if (c.role == 'admin') OutlinedButton.icon(onPressed: busy ? null : _showCode, icon: const Icon(Icons.qr_code_2), label: Text(tr('link_new_device'))),
            OutlinedButton.icon(onPressed: busy ? null : _disconnect, icon: const Icon(Icons.link_off), label: Text(tr('link_disconnect'))),
          ]),
        ]),
        if (c.role == 'admin') ...[const SizedBox(height: 16), _devicesCard()],
      ];

  Widget _devicesCard() => _card([
        Text(tr('link_devices'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (devices.isEmpty) Text(tr('link_no_devices'), style: const TextStyle(color: C.muted)),
        for (final d in devices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(d['revoked_at'] != null ? Icons.phonelink_erase : Icons.smartphone, color: d['revoked_at'] != null ? Colors.red : C.teal),
            title: Text('${d['device_name'] ?? '-'}${d['device_id'] == device ? '  (${tr('link_this_device')})' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${d['revoked_at'] != null ? tr('link_revoked') : _roleLabel(d['role'] as String?)} • ${tr('link_last_seen')}: ${_fmt(d['last_seen_at'])}'),
            trailing: (d['device_id'] == device || d['revoked_at'] != null)
                ? null
                : TextButton(onPressed: busy ? null : () => _revoke('${d['device_id']}'), child: Text(tr('link_revoke'), style: TextStyle(color: Colors.red.shade700))),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final linked = CloudService.user != null ? church : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('sync_title'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: C.navy)),
            const SizedBox(height: 6),
            Text(tr('sync_subtitle'), style: const TextStyle(color: C.muted)),
            const SizedBox(height: 20),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (!CloudService.available)
              _card([Text(CloudConfig.missingMessage() ?? '', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700))])
            else if (linked == null)
              ..._unlinked()
            else
              ..._linked(linked),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(status!, style: TextStyle(color: ok ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: C.navy.withOpacity(.045), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.navy.withOpacity(.10))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('cloud_security_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(tr('cloud_security_body'), style: const TextStyle(color: C.text, height: 1.5)),
                const SizedBox(height: 8),
                Text(tr('sync_local_first'), style: const TextStyle(fontWeight: FontWeight.w700, color: C.teal)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
