import 'dart:async';
import 'package:flutter/material.dart';
import 'core/auth.dart';
import 'core/db.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/cloud_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootApp());
}

/// Inaonyesha SplashScreen (logo) wakati database, cloud na lugha vinapakiwa,
/// kisha inafungua app. Splash inaonekana angalau sekunde ~2 ili logo ionekane vizuri.
class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  bool _ready = false;
  String? _error;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (mounted) setState(() => _error = null);
    final started = DateTime.now();
    try {
      await AppDb.instance.init();
      await CloudService.initialize();
      await L10n.instance.load();
      _syncTimer ??= Timer.periodic(const Duration(minutes: 1), (_) async {
        if (CloudService.available && CloudService.user != null) {
          try { await CloudService.sync(); } catch (_) {}
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Imeshindikana kufungua app: $e');
      return;
    }
    final left = const Duration(milliseconds: 2000) - DateTime.now().difference(started);
    if (!left.isNegative) await Future<void>.delayed(left);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const MfukoApp();
    return MaterialApp(
      title: 'MFUKO WA MAPATO YA KANISA',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: SplashScreen(error: _error, onRetry: _error == null ? null : _boot),
    );
  }
}

class MfukoApp extends StatelessWidget {
  const MfukoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MFUKO WA MAPATO YA KANISA',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Gate(),
    );
  }
}

/// Inaamua: kuunda PIN (mara ya kwanza), kuingia kwa PIN, au kuonyesha app.
class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool? _hasPin;
  bool _in = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await Auth.hasPin();
    if (mounted) setState(() => _hasPin = h);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_in) {
      return LoginScreen(
        setup: !_hasPin!,
        onSuccess: () => setState(() {
          _in = true;
          _hasPin = true;
        }),
      );
    }
    return AppShell(onLogout: () => setState(() => _in = false));
  }
}
