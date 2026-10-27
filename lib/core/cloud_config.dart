import 'package:flutter/foundation.dart';
import 'i18n.dart';

/// Public Supabase configuration is supplied at build time.
/// Never put a Supabase secret/service-role key in the app.
class CloudConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get configured =>
      url.trim().startsWith('https://') && publishableKey.trim().isNotEmpty;

  static String? missingMessage() {
    if (configured) return null;
    return tr('cloud_config_missing');
  }
}
