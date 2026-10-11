import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/auth.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/lang_toggle.dart';
import '../widgets/powered_by.dart';
import 'link_device_page.dart';
import '../services/cloud_service.dart';

class LoginScreen extends StatefulWidget {
  /// true = mara ya kwanza, mtumiaji anatengeneza PIN.
  final bool setup;
  final VoidCallback onSuccess;
  const LoginScreen({super.key, required this.setup, required this.onSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error; // ufunguo wa tafsiri
  String _errorExtra = ''; // maelezo ya ziada (mfano majaribio yaliyobaki)
  bool _recovery = false; // majaribio 5 mabaya -> PIN ya muda inaruhusiwa
  bool _tempOk = false; // PIN ya muda imekubaliwa -> weka PIN mpya

  @override
  void initState() {
    super.initState();
    if (!widget.setup) _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    final n = await Auth.failedAttempts();
    if (mounted && n >= Auth.maxAttempts) {
      setState(() {
        _recovery = true;
        _error = 'pin_recovery_msg';
      });
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _cloudLogin() async {
    if (!CloudService.available) {
      setState(() => _error = 'cloud_not_configured');
      return;
    }
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LinkDevicePage())) ?? false;
    if (!ok || !mounted) return;
    if (widget.setup) {
      final pin = await showDialog<String>(context: context, barrierDismissible: false, builder: (context) {
        final a = TextEditingController(); final b = TextEditingController();
        return AlertDialog(
          title: Text(tr('create_pin')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('cloud_local_pin_hint'), style: const TextStyle(color: C.muted)),
            const SizedBox(height: 12),
            TextField(controller: a, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: InputDecoration(labelText: tr('pin'))),
            TextField(controller: b, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: InputDecoration(labelText: tr('pin_confirm'))),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))), ElevatedButton(onPressed: () { if (a.text.length >= 4 && a.text == b.text) Navigator.pop(context, a.text); }, child: Text(tr('save_pin')))],
        );
      });
      if (pin == null) return;
      await Auth.setPin(pin);
    }
    await AppDb.instance.audit('CLOUD_LINK_LOGIN');
    widget.onSuccess();
  }

  Future<void> _submit() async {
    final p = _pin.text.trim();
    if (widget.setup) {
      if (p.length < 4 || p.length > 8) {
        setState(() => _error = 'pin_short');
        return;
      }
      if (p != _pin2.text.trim()) {
        setState(() => _error = 'pin_mismatch');
        return;
      }
      await Auth.setPin(p);
      await AppDb.instance.audit('PIN_CREATED');
      widget.onSuccess();
    } else if (_tempOk) {
      // Hatua ya mwisho ya kurejesha: weka PIN mpya.
      if (p.length < 4 || p.length > 8) {
        setState(() { _error = 'pin_short'; _errorExtra = ''; });
        return;
      }
      if (Auth.isTempPin(p)) {
        setState(() { _error = 'pin_temp_not_allowed'; _errorExtra = ''; });
        return;
      }
      if (p != _pin2.text.trim()) {
        setState(() { _error = 'pin_mismatch'; _errorExtra = ''; });
        return;
      }
      await Auth.setPin(p);
      await Auth.resetFailures();
      await AppDb.instance.audit('PIN_RESET_TEMP');
      widget.onSuccess();
    } else if (_recovery && Auth.isTempPin(p)) {
      // PIN ya muda sahihi -> onyesha mafanikio kisha aweke PIN mpya.
      _pin.clear();
      _pin2.clear();
      setState(() {
        _tempOk = true;
        _error = null;
        _errorExtra = '';
      });
    } else {
      if (await Auth.verify(p)) {
        await Auth.resetFailures();
        await AppDb.instance.audit('LOGIN');
        widget.onSuccess();
      } else {
        final n = await Auth.registerFailure();
        _pin.clear();
        if (n >= Auth.maxAttempts) {
          await AppDb.instance.audit('PIN_LOCK_RECOVERY');
          setState(() {
            _recovery = true;
            _error = 'pin_recovery_msg';
            _errorExtra = '';
          });
        } else {
          setState(() {
            _error = 'pin_wrong';
            _errorExtra = ' • ${tr('pin_attempts_left')}: ${Auth.maxAttempts - n}';
          });
        }
      }
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(color: C.navy),
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.church, size: 54, color: C.gold),
                              const SizedBox(height: 10),
                              Text(tr('app_name'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: C.navy)),
                              const SizedBox(height: 4),
                              Text(tr('tagline'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12.5, color: C.muted)),
                              const SizedBox(height: 22),
                              if (_tempOk) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.check_circle, color: Colors.green),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(tr('temp_pin_ok'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700))),
                                  ]),
                                ),
                              ],
                              Text(
                                  (widget.setup || _tempOk)
                                      ? tr('create_pin')
                                      : (_recovery ? tr('temp_pin') : tr('enter_pin')),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: C.text)),
                              const SizedBox(height: 4),
                              Text(
                                  _tempOk
                                      ? tr('temp_pin_ok_sub')
                                      : (widget.setup ? tr('create_pin_sub') : tr('enter_pin_sub')),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12.5, color: C.muted)),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _pin,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                maxLength: 8,
                                autofocus: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                decoration: _dec(_tempOk ? tr('new_pin') : (_recovery ? tr('temp_pin') : tr('pin'))).copyWith(counterText: ''),
                                onSubmitted: (_) =>
                                    (widget.setup || _tempOk) ? null : _submit(),
                              ),
                              if (widget.setup || _tempOk) ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _pin2,
                                  obscureText: true,
                                  keyboardType: TextInputType.number,
                                  maxLength: 8,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  decoration: _dec(tr('pin_confirm'))
                                      .copyWith(counterText: ''),
                                  onSubmitted: (_) => _submit(),
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(tr(_error!) + _errorExtra,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: _recovery && !_tempOk ? Colors.orange.shade800 : Colors.red,
                                        fontSize: 13)),
                              ],
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  child: Text(_tempOk ? tr('new_pin_save') : (widget.setup ? tr('save_pin') : tr('login'))),
                                ),
                              ),
                              if (_tempOk)
                                TextButton(
                                  onPressed: () => setState(() { _tempOk = false; _pin.clear(); _pin2.clear(); _error = 'pin_recovery_msg'; _errorExtra = ''; }),
                                  child: Text(tr('cancel')),
                                ),
                              if (CloudService.available && !_tempOk) ...[
                                const SizedBox(height: 10),
                                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _cloudLogin, icon: const Icon(Icons.qr_code_scanner), label: Text(tr('link_join_btn')))),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 12,
                    right: 16,
                    child: LangToggle(onDark: true),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Center(child: PoweredBy(onDark: true)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
