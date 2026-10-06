import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/powered_by.dart';

/// Skrini ya kupakia: logo katikati (nafasi ileile na launch screen ya Android
/// ili mpito usiruke), jina la app, na kiashiria cha kupakia.
class SplashScreen extends StatelessWidget {
  final String? error;
  final VoidCallback? onRetry;
  const SplashScreen({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(child: Image.asset('assets/logo.png', width: 144, height: 144)),
            Align(
              alignment: const Alignment(0, .52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('MFUKO WA MAPATO YA KANISA',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: C.navy, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: .5)),
                    const SizedBox(height: 16),
                    if (error == null)
                      const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: C.teal))
                    else ...[
                      Text(error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
                      const SizedBox(height: 10),
                      if (onRetry != null) OutlinedButton(onPressed: onRetry, child: const Text('Jaribu tena / Retry')),
                    ],
                  ],
                ),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(padding: EdgeInsets.only(bottom: 22), child: PoweredBy()),
            ),
          ],
        ),
      ),
    );
  }
}
