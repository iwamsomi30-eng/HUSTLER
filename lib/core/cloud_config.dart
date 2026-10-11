import 'package:flutter/foundation.dart';

/// Public Supabase configuration is supplied at build time.
/// Never put a Supabase secret/service-role key in the app.
class CloudConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get configured =>
      url.trim().startsWith('https://') && publishableKey.trim().isNotEmpty;

  static String? missingMessage() {
    if (configured) return null;
    return 'Cloud haijawekwa kwenye toleo hili la app. Pakua toleo jipya lililotengenezwa baada ya kuweka Supabase secrets, au wasiliana na msimamizi wa mfumo.';
  }
}
