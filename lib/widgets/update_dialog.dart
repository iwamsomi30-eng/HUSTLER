import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/update_service.dart';

/// Dirisha la "Toleo jipya linapatikana". Mtumiaji anaweza kuchagua "Baadaye".
Future<void> showUpdateDialog(BuildContext context, UpdateInfo u) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(info: u),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  double _p = 0;
  String? _msg;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _p = 0;
      _msg = null;
    });
    final r = await UpdateService.instance.downloadAndInstall(
      widget.info,
      onProgress: (v) {
        if (mounted) setState(() => _p = v);
      },
    );
    if (!mounted) return;
    switch (r) {
      case InstallResult.started:
      case InstallResult.openedBrowser:
        Navigator.of(context).pop();
        break;
      case InstallResult.needsPermission:
        setState(() {
          _busy = false;
          _msg = tr('upd_need_perm');
        });
        break;
      case InstallResult.failed:
        setState(() {
          _busy = false;
          _msg = tr('upd_failed');
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.info;
    final mb = u.assetSize > 0 ? ' (${(u.assetSize / 1048576).toStringAsFixed(1)} MB)' : '';
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Row(children: [
        const Icon(Icons.system_update, color: C.blue),
        const SizedBox(width: 10),
        Expanded(
          child: Text('${tr('upd_title')} ${u.version}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy, fontSize: 18)),
        ),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${tr('upd_body')}$mb', style: const TextStyle(color: C.text)),
              if (u.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(tr('upd_whats_new'),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: C.navy)),
                const SizedBox(height: 4),
                Text(u.notes, style: const TextStyle(color: C.text, height: 1.35)),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _p > 0 ? _p : null, color: C.blue),
                const SizedBox(height: 4),
                Text(_p > 0 ? '${(_p * 100).toStringAsFixed(0)}%' : tr('upd_downloading'),
                    style: const TextStyle(color: C.muted, fontSize: 12)),
              ],
              if (_msg != null) ...[
                const SizedBox(height: 12),
                Text(_msg!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 10),
              Text(tr('upd_optional'), style: const TextStyle(color: C.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(tr('upd_later')),
        ),
        ElevatedButton.icon(
          onPressed: _busy ? null : _go,
          icon: const Icon(Icons.download),
          label: Text(tr('upd_now')),
          style: ElevatedButton.styleFrom(backgroundColor: C.blue),
        ),
      ],
    );
  }
}
