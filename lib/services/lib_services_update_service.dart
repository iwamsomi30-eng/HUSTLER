import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/update_config.dart';

class UpdateInfo {
  final String version; // mf. 0.10.0
  final int build; // mf. 10
  final String notes;
  final String? assetUrl; // APK (Android) au ZIP (Windows)
  final int assetSize;
  final String pageUrl;
  const UpdateInfo({
    required this.version,
    required this.build,
    required this.notes,
    required this.assetUrl,
    required this.assetSize,
    required this.pageUrl,
  });
}

enum InstallResult { started, needsPermission, failed, openedBrowser }

/// Inaangalia GitHub Releases za repo yako na kuonyesha kama kuna toleo jipya.
/// Haimlazimishi mtu: asipo-update app inaendelea kufanya kazi kama kawaida.
class UpdateService extends ChangeNotifier {
  UpdateService._();
  static final UpdateService instance = UpdateService._();
  static const _ch = MethodChannel('mfuko/update');

  UpdateInfo? available;
  bool checking = false;
  DateTime? _lastCheck;

  /// Angalia toleo jipya. [force] inapita kikomo cha dakika 10 (kwa kitufe cha mkono).
  /// Inarudisha true kama ukaguzi ulifanikiwa (hata kama hakuna update),
  /// false kama imeshindikana (mf. hakuna internet).
  Future<bool> check({bool force = false}) async {
    if (!UpdateConfig.enabled || checking) return true;
    final now = DateTime.now();
    if (!force &&
        _lastCheck != null &&
        now.difference(_lastCheck!).inMinutes < 10) {
      return true;
    }
    checking = true;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final req = await client.getUrl(Uri.parse(
            'https://api.github.com/repos/${UpdateConfig.repo}/releases/latest'));
        req.headers.set('Accept', 'application/vnd.github+json');
        req.headers.set('User-Agent', 'mfuko-wa-kanisa-updater');
        final res = await req.close().timeout(const Duration(seconds: 15));
        final body = await res.transform(utf8.decoder).join();
        if (res.statusCode != 200) {
          // 404 = hakuna release bado (au repo ni private). Si hitilafu ya mtumiaji.
          available = null;
          _lastCheck = now;
          notifyListeners();
          return res.statusCode == 404;
        }
        final j = jsonDecode(body) as Map<String, dynamic>;
        final tag = '${j['tag_name'] ?? ''}'.trim().replaceFirst(RegExp('^[vV]'), '');
        final parts = tag.split('+');
        final ver = parts.first;
        final build = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        final info = await PackageInfo.fromPlatform();
        final curBuild = int.tryParse(info.buildNumber) ?? 0;
        String? url;
        int size = 0;
        final wantExt = Platform.isAndroid ? '.apk' : '.zip';
        for (final a in (j['assets'] as List? ?? const [])) {
          final name = '${a['name']}'.toLowerCase();
          if (name.endsWith(wantExt)) {
            url = '${a['browser_download_url']}';
            size = (a['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
        if (_isNewer(ver, build, info.version, curBuild)) {
          available = UpdateInfo(
            version: ver,
            build: build,
            notes: '${j['body'] ?? ''}'.trim(),
            assetUrl: url,
            assetSize: size,
            pageUrl: '${j['html_url'] ?? 'https://github.com/${UpdateConfig.repo}/releases'}',
          );
        } else {
          available = null;
        }
        _lastCheck = now;
        notifyListeners();
        return true;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return false;
    } finally {
      checking = false;
    }
  }

  static bool _isNewer(String v, int b, String curV, int curB) {
    List<int> p(String s) =>
        s.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
    final a = p(v), c = p(curV);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < c.length ? c[i] : 0;
      if (x != y) return x > y;
    }
    return b > curB;
  }

  /// Android: pakua APK ndani ya app kisha fungua installer ya simu.
  /// Windows/nyingine: fungua link ya kupakua kwenye browser.
  Future<InstallResult> downloadAndInstall(
    UpdateInfo u, {
    required void Function(double progress) onProgress,
  }) async {
    final link = u.assetUrl ?? u.pageUrl;
    if (!Platform.isAndroid || u.assetUrl == null) {
      final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      return ok ? InstallResult.openedBrowser : InstallResult.failed;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/mfuko_update.apk');
    if (await file.exists()) await file.delete();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(u.assetUrl!));
      req.headers.set('User-Agent', 'mfuko-wa-kanisa-updater');
      req.followRedirects = true;
      req.maxRedirects = 8;
      final res = await req.close();
      if (res.statusCode != 200) return InstallResult.failed;
      final total = res.contentLength > 0 ? res.contentLength : u.assetSize;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress((got / total).clamp(0.0, 1.0));
      }
      await sink.flush();
      await sink.close();
      if (total > 0 && got < total) {
        await file.delete();
        return InstallResult.failed;
      }
      final r = await _ch.invokeMethod<String>('installApk', {'path': file.path});
      if (r == 'needs_permission') return InstallResult.needsPermission;
      return r == 'started' ? InstallResult.started : InstallResult.failed;
    } catch (_) {
      return InstallResult.failed;
    } finally {
      client.close(force: true);
    }
  }
}
