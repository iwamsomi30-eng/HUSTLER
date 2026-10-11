import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Matokeo ya kuhifadhi faili kwenye kifaa.
class SavedFile {
  /// Mahali faili lilipohifadhiwa (kama linajulikana).
  final String? path;

  /// Jina la faili.
  final String name;

  /// true = mtumiaji alighairi dirisha la "Hifadhi".
  final bool cancelled;

  const SavedFile({required this.name, this.path, this.cancelled = false});

  /// Njia ya faili inayosomeka (si content:// URI), au null.
  String? get displayPath {
    final v = path;
    if (v == null || v.startsWith('content:')) return null;
    return v.contains('/') || v.contains('\\') ? v : null;
  }
}

/// Inahifadhi faili moja kwa moja kwenye kifaa cha mtumiaji:
///  - Windows / Linux / macOS: inaandika moja kwa moja kwenye folda ya Downloads (bila dirisha).
///  - Android / iOS: inafungua dirisha la mfumo la "Hifadhi" (jina tayari limeandikwa,
///    Downloads ndiyo folda ya kwanza) - bonyeza "Hifadhi" mara moja tu.
class FileSaver {
  static bool get _desktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static String _uniquePath(String path) {
    if (!File(path).existsSync()) return path;
    final dir = p.dirname(path);
    final base = p.basenameWithoutExtension(path);
    final ext = p.extension(path);
    var i = 1;
    while (File(p.join(dir, '$base ($i)$ext')).existsSync()) {
      i++;
    }
    return p.join(dir, '$base ($i)$ext');
  }

  static Future<SavedFile> saveBytes(String fileName, Uint8List bytes) async {
    if (_desktop) {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      await dir.create(recursive: true);
      final path = _uniquePath(p.join(dir.path, fileName));
      await File(path).writeAsBytes(bytes, flush: true);
      return SavedFile(name: p.basename(path), path: path);
    }
    final res = await FilePicker.platform.saveFile(
      dialogTitle: fileName,
      fileName: fileName,
      bytes: bytes,
    );
    if (res == null) return SavedFile(name: fileName, cancelled: true);
    return SavedFile(name: fileName, path: res);
  }
}
