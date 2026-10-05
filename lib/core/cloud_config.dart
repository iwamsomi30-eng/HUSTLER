import 'package:flutter/foundation.dart';

/// Public Supabase configuration is supplied at build time.
/// Never put a Supabase secret/service-role key in the app.
class CloudConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get configured => url.isNotEmpty && publishableKey.isNotEmpty;

  static String? missingMessage() {
    if (configured) return null;
    return 'Cloud haija-configurewa. Tumia --dart-define=SUPABASE_URL=... na SUPABASE_PUBLISHABLE_KEY=...';
  }
}
