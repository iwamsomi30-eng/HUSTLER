import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/cloud_service.dart';

/// Kifaa kilichounganishwa (Admin) kinaonyesha QR + OTP ya kuunganisha kifaa kipya.
class LinkCodeDialog extends StatefulWidget {
  const LinkCodeDialog({super.key});
  @override
  State<LinkCodeDialog> createState() => _LinkCodeDialogState();
}

class _LinkCodeDialogState extends State<LinkCodeDialog> {
  String _role = 'editor';
  LinkCode? _code;
  bool _busy = false;
  String? _error;
  String? _usedBy; // jina la kifaa kilichounganishwa
  Timer? _tick;
  int _polls = 0;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _secondsLeft => _code == null ? 0 : _code!.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 3600).toInt();
  bool get _expired => _code != null && _usedBy == null && _secondsLeft == 0;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
      _usedBy = null;
    });
    try {
      final c = await CloudService.createLinkCode(role: _role);
      _tick?.cancel();
      _polls = 0;
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      if (mounted) setState(() => _code = c);
    } catch (_) {
      if (mounted) setState(() => _error = 'cloud_network_error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onTick() async {
    if (!mounted || _code == null) return;
    if (_usedBy != null || _secondsLeft == 0) {
      _tick?.cancel();
      setState(() {});
      return;
    }
    setState(() {}); // sasisha countdown
    _polls++;
    if (_polls % 3 == 0) {
      try {
        final used = await CloudService.linkCodeUsedBy(_code!.id);
        if (used != null && mounted) {
          _tick?.cancel();
          setState(() => _usedBy = used);
        }
      } catch (_) {}
    }
  }

  String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final active = _code != null && _usedBy == null && !_expired;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.qr_code_2, color: C.teal),
        const SizedBox(width: 10),
        Expanded(child: Text(tr('link_new_device'))),
      ]),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('link_code_sub'), style: const TextStyle(color: C.muted)),
            const SizedBox(height: 14),
            if (_usedBy != null) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 8),
              Text('${tr('link_code_used')} ${_usedBy!}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ] else if (active) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
                  child: QrImageView(data: _code!.qrPayload, version: QrVersions.auto, size: 210, backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: InkWell(
                  onTap: () => Clipboard.setData(ClipboardData(text: _code!.code)),
                  child: Text(_code!.codeDisplay, style: const TextStyle(fontSize: 34, letterSpacing: 4, fontWeight: FontWeight.w900, color: C.navy)),
                ),
              ),
              const SizedBox(height: 6),
              Center(child: Text('${tr('link_code_expires_in')} ${_mmss(_secondsLeft)}', style: const TextStyle(fontWeight: FontWeight.w700, color: C.teal))),
              const SizedBox(height: 6),
              Text(tr('link_code_once'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 12.5)),
            ] else ...[
              if (_expired) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(tr('link_code_expired'), style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700))),
              Text(tr('link_code_role'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.teal.withOpacity(.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.teal.withOpacity(.22))),
                child: Text(tr('role_editor_desc'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _busy ? null : _generate,
                icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.qr_code),
                label: Text(_expired ? tr('link_code_regen') : tr('link_code_generate')),
              ),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(tr(_error!), style: TextStyle(color: Colors.red.shade700))),
          ]),
        ),
      ),
      actions: [
        if (active) TextButton(onPressed: _busy ? null : _generate, child: Text(tr('link_code_regen'))),
        TextButton(onPressed: () => Navigator.pop(context, _usedBy != null), child: Text(tr('link_close'))),
      ],
    );
  }
}
