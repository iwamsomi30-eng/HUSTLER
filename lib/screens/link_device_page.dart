import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/cloud_service.dart';

/// Kifaa KIPYA kinaunganishwa na kifaa kilichounganishwa tayari kwa QR au OTP tu.
/// Inarudisha `true` (Navigator.pop) baada ya kuunganishwa na data kupokelewa.
class LinkDevicePage extends StatefulWidget {
  const LinkDevicePage({super.key});
  @override
  State<LinkDevicePage> createState() => _LinkDevicePageState();
}

class _LinkDevicePageState extends State<LinkDevicePage> {
  final _name = TextEditingController(text: CloudService.defaultDeviceName());
  final _otp = TextEditingController();
  MobileScannerController? _scanner;
  bool _busy = false;
  String? _error; // ufunguo wa tafsiri
  String? _lastFailedQr;

  bool get _canScan =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_canScan) _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  }

  @override
  void dispose() {
    _scanner?.dispose();
    _name.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _link(String secret, {String? qr}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CloudService.redeemLink(secret, deviceName: _name.text);
      // Pokea data zote za kanisa mara moja.
      try {
        await CloudService.sync();
      } catch (_) {/* sync ya kawaida itajaribu tena kila dakika */}
      await AppDb.instance.audit('DEVICE_LINKED');
      if (!mounted) return;
      Navigator.pop(context, true);
    } on LinkException catch (e) {
      _lastFailedQr = qr;
      if (mounted) setState(() => _error = e.code == 'TOO_MANY' ? 'link_too_many' : 'link_invalid');
    } on AuthException catch (_) {
      if (mounted) setState(() => _error = 'cloud_anon_disabled');
    } catch (_) {
      if (mounted) setState(() => _error = 'cloud_network_error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.startsWith(LinkCode.qrPrefix) && v != _lastFailedQr) {
        _link(v, qr: v);
        return;
      }
    }
  }

  void _submitOtp() {
    final code = _otp.text.trim();
    if (code.length != 8) {
      setState(() => _error = 'link_otp_short');
      return;
    }
    _link(code);
  }

  Widget _deviceName() => TextField(
        controller: _name,
        maxLength: 40,
        enabled: !_busy,
        decoration: InputDecoration(
          labelText: tr('link_device_name'),
          prefixIcon: const Icon(Icons.devices_outlined),
          counterText: '',
        ),
      );

  Widget _scanTab() {
    if (!_canScan) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(tr('link_scan_unavailable'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted))));
    }
    return Column(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(color: Colors.black, child: MobileScanner(controller: _scanner!, onDetect: _onDetect)),
        ),
      ),
      const SizedBox(height: 10),
      Text(tr('link_scan_hint'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 12.5)),
    ]);
  }

  Widget _otpTab() => SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('link_otp_hint'), style: const TextStyle(color: C.muted)),
          const SizedBox(height: 14),
          TextField(
            controller: _otp,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: 8,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.w800, color: C.navy),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: tr('link_otp_label'), counterText: ''),
            onSubmitted: (_) => _submitOtp(),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _busy ? null : _submitOtp,
            icon: const Icon(Icons.link),
            label: Text(tr('link_btn')),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      if (_canScan) Tab(icon: const Icon(Icons.qr_code_scanner), text: tr('link_scan_tab')),
      Tab(icon: const Icon(Icons.pin_outlined), text: tr('link_otp_tab')),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(title: Text(tr('link_page_title'))),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _deviceName(),
                  const SizedBox(height: 8),
                  TabBar(tabs: tabs),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [if (_canScan) _scanTab(), _otpTab()],
                    ),
                  ),
                  if (_busy)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Text(tr('link_busy_sync')),
                      ]),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(tr(_error!), textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
