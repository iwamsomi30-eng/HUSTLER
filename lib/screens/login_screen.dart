import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/auth.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/lang_toggle.dart';
import 'cloud_login_dialog.dart';
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
    final ok = await showDialog<bool>(context: context, builder: (_) => const CloudLoginDialog()) ?? false;
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
    await AppDb.instance.audit('CLOUD_LOGIN', CloudService.user?.email);
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
    } else {
      if (await Auth.verify(p)) {
        await AppDb.instance.audit('LOGIN');
        widget.onSuccess();
      } else {
        _pin.clear();
        setState(() => _error = 'pin_wrong');
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [C.navy, C.navyDark],
              ),
            ),
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
                              Text(
                                  widget.setup
                                      ? tr('create_pin')
                                      : tr('enter_pin'),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: C.text)),
                              const SizedBox(height: 4),
                              Text(
                                  widget.setup
                                      ? tr('create_pin_sub')
                                      : tr('enter_pin_sub'),
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
                                decoration:
                                    _dec(tr('pin')).copyWith(counterText: ''),
                                onSubmitted: (_) =>
                                    widget.setup ? null : _submit(),
                              ),
                              if (widget.setup) ...[
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
                                Text(tr(_error!),
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 13)),
                              ],
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  child: Text(widget.setup ? tr('save_pin') : tr('login')),
                                ),
                              ),
                              if (CloudService.available) ...[
                                const SizedBox(height: 10),
                                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _cloudLogin, icon: const Icon(Icons.cloud_outlined), label: Text(tr('cloud_login')))),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
