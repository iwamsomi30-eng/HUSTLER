import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/update_config.dart';

class UpdateInfo {
  final String version; // mf. 0.13.0
  final int build; // mf. 15
  final String notes;
  final String? assetUrl; // APK (Android) au Setup.exe (Windows)
  final int assetSize;
  final String pageUrl;

  /// true = lazima kusasisha (toleo la sasa limeshapitwa na `minBuild`
  /// au umewasha `force` kwenye Firestore). Dirisha halina "Baadaye".
  final bool required;
  const UpdateInfo({
    required this.version,
    required this.build,
    required this.notes,
    required this.assetUrl,
    required this.assetSize,
    required this.pageUrl,
    this.required = false,
  });
}

enum InstallResult { started, needsPermission, failed, openedBrowser }

class _Fetch {
  final bool ok; // false = hitilafu ya mtandao/seva
  final bool found; // true = chanzo hiki kimetoa jibu halali
  final UpdateInfo? update; // null = hakuna toleo jipya
  const _Fetch({required this.ok, required this.found, this.update});
}

/// Inaangalia toleo jipya (Firestore kwanza, kisha GitHub Releases kama akiba).
/// Isipokuwa update ya lazima, haimlazimishi mtu: asipo-update app inaendelea.
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
      final info = await PackageInfo.fromPlatform();
      final curBuild = int.tryParse(info.buildNumber) ?? 0;

      _Fetch r = await _fromFirestore(info.version, curBuild);
      if (!r.found && UpdateConfig.githubEnabled) {
        final g = await _fromGithub(info.version, curBuild);
        // Kama Firestore ilishindwa mtandaoni na GitHub nayo, ni hitilafu.
        r = _Fetch(ok: g.ok || r.ok, found: g.found, update: g.update);
      }
      if (!r.found && !r.ok) return false;
      available = r.update;
      _lastCheck = now;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    } finally {
      checking = false;
    }
  }

  // ---------------------------------------------------------------------
  // FIRESTORE (REST)  ->  app_updates/android  |  app_updates/windows
  // ---------------------------------------------------------------------

  static String? _str(Map f, String k) {
    final v = f[k];
    if (v is Map && v['stringValue'] != null) return '${v['stringValue']}'.trim();
    return null;
  }

  static int _int(Map f, String k) {
    final v = f[k];
    if (v is Map) {
      if (v['integerValue'] != null) return int.tryParse('${v['integerValue']}') ?? 0;
      if (v['doubleValue'] != null) return (v['doubleValue'] as num).toInt();
      if (v['stringValue'] != null) return int.tryParse('${v['stringValue']}') ?? 0;
    }
    return 0;
  }

  static bool _bool(Map f, String k) {
    final v = f[k];
    return v is Map && v['booleanValue'] == true;
  }

  Future<_Fetch> _fromFirestore(String curV, int curB) async {
    final docName = Platform.isAndroid
        ? 'android'
        : (Platform.isWindows ? 'windows' : null);
    if (!UpdateConfig.firestoreEnabled || docName == null) {
      return const _Fetch(ok: true, found: false);
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      var url = 'https://firestore.googleapis.com/v1/projects/'
          '${UpdateConfig.firebaseProjectId}/databases/(default)/documents/'
          'app_updates/$docName';
      if (UpdateConfig.firebaseApiKey.isNotEmpty) {
        url += '?key=${Uri.encodeQueryComponent(UpdateConfig.firebaseApiKey)}';
      }
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await res.transform(utf8.decoder).join();
      // 404 = hati bado haijaundwa. Si hitilafu ya mtumiaji.
      if (res.statusCode == 404) return const _Fetch(ok: true, found: false);
      if (res.statusCode != 200) return const _Fetch(ok: false, found: false);

      final f = ((jsonDecode(body) as Map)['fields'] as Map?) ?? const {};
      final ver = (_str(f, 'version') ?? '').replaceFirst(RegExp('^[vV]'), '');
      if (ver.isEmpty) return const _Fetch(ok: true, found: false);
      final build = _int(f, 'build');
      final minBuild = _int(f, 'minBuild');
      final forced = _bool(f, 'force');
      final newer = _isNewer(ver, build, curV, curB);
      final mustUpdate = (minBuild > 0 && curB < minBuild) || (forced && newer);
      if (!newer && !mustUpdate) return const _Fetch(ok: true, found: true);

      final link = _str(f, 'url');
      return _Fetch(
        ok: true,
        found: true,
        update: UpdateInfo(
          version: ver,
          build: build,
          notes: _str(f, 'notes') ?? '',
          assetUrl: (link != null && link.isNotEmpty) ? link : null,
          assetSize: _int(f, 'size'),
          pageUrl: _str(f, 'pageUrl') ??
              (UpdateConfig.githubEnabled
                  ? 'https://github.com/${UpdateConfig.repo}/releases'
                  : ''),
          required: mustUpdate,
        ),
      );
    } catch (_) {
      return const _Fetch(ok: false, found: false);
    } finally {
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------------------
  // GITHUB RELEASES (akiba)
  // ---------------------------------------------------------------------

  Future<_Fetch> _fromGithub(String curV, int curB) async {
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
        return _Fetch(ok: res.statusCode == 404, found: res.statusCode == 404);
      }
      final j = jsonDecode(body) as Map<String, dynamic>;
      final tag = '${j['tag_name'] ?? ''}'.trim().replaceFirst(RegExp('^[vV]'), '');
      final parts = tag.split('+');
      final ver = parts.first;
      final build = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      String? url;
      int size = 0;
      final wantExt = Platform.isAndroid ? '.apk' : '.exe';
      for (final a in (j['assets'] as List? ?? const [])) {
        final name = '${a['name']}'.toLowerCase();
        if (name.endsWith(wantExt)) {
          url = '${a['browser_download_url']}';
          size = (a['size'] as num?)?.toInt() ?? 0;
          break;
        }
      }
      if (!_isNewer(ver, build, curV, curB)) {
        return const _Fetch(ok: true, found: true);
      }
      return _Fetch(
        ok: true,
        found: true,
        update: UpdateInfo(
          version: ver,
          build: build,
          notes: '${j['body'] ?? ''}'.trim(),
          assetUrl: url,
          assetSize: size,
          pageUrl: '${j['html_url'] ?? 'https://github.com/${UpdateConfig.repo}/releases'}',
        ),
      );
    } catch (_) {
      return const _Fetch(ok: false, found: false);
    } finally {
      client.close(force: true);
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

  // ---------------------------------------------------------------------
  // KUSAKINISHA
  // ---------------------------------------------------------------------

  /// Android: pakua APK ndani ya app kisha fungua installer ya simu.
  /// Windows: pakua Setup.exe, ifunge app, sakinisha kimya kimya, kisha
  /// ifungue app tena (ikishindikana, inafungua link kwenye browser).
  Future<InstallResult> downloadAndInstall(
    UpdateInfo u, {
    required void Function(double progress) onProgress,
  }) async {
    final link = u.assetUrl ?? u.pageUrl;
    final canInApp = u.assetUrl != null && (Platform.isAndroid || Platform.isWindows);
    if (!canInApp) {
      if (link.isEmpty) return InstallResult.failed;
      final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      return ok ? InstallResult.openedBrowser : InstallResult.failed;
    }
    final dir = await getTemporaryDirectory();
    final file = File(Platform.isAndroid
        ? '${dir.path}/mfuko_update.apk'
        : '${dir.path}\\mfuko_update_setup.exe');
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
      if (Platform.isWindows) return await _installWindows(file.path, dir.path);
      final r = await _ch.invokeMethod<String>('installApk', {'path': file.path});
      if (r == 'needs_permission') return InstallResult.needsPermission;
      return r == 'started' ? InstallResult.started : InstallResult.failed;
    } catch (_) {
      return InstallResult.failed;
    } finally {
      client.close(force: true);
    }
  }

  /// Windows: andika script ndogo (.bat) inayoendesha Setup kimya kimya kwenye
  /// folda ile ile ya app, kisha kuifungua app tena. App hii inajifunga.
  Future<InstallResult> _installWindows(String setupPath, String tmpDir) async {
    try {
      final exe = Platform.resolvedExecutable;
      final appDir = File(exe).parent.path;
      final bat = File('$tmpDir\\mfuko_update.bat');
      await bat.writeAsString(
        '@echo off\r\n'
        'timeout /t 2 /nobreak >nul\r\n'
        '"$setupPath" /SILENT /NORESTART /CLOSEAPPLICATIONS /DIR="$appDir"\r\n'
        'start "" "$exe"\r\n',
      );
      await Process.start('cmd', ['/c', bat.path], mode: ProcessStartMode.detached);
      Future.delayed(const Duration(milliseconds: 800), () => exit(0));
      return InstallResult.started;
    } catch (_) {
      return InstallResult.failed;
    }
  }
}
