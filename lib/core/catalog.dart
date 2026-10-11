import 'package:flutter/material.dart';
import 'db.dart';

enum NameKind { contribution, expenditure }

/// Orodha ya majina ya michango na ya matumizi.
/// Orodha = majina ya msingi + majina yaliyoongezwa na mtumiaji + majina
/// yaliyokwisha kutumika kwenye rekodi (kwa hiyo data ya zamani haipotei).
class NameCatalog {
  /// Jina la mchango linalotumia Bahasha (Fungu).
  static const fungu = 'FUNGU';

  static const contributionDefaults = <String>[
    'FUNGU', 'INJILI', 'UJENZI', 'WAJANE', 'MAANDIKO', 'SHUKRANI', 'UMISHENI', 'SADAKA',
  ];

  static const expenditureDefaults = <String>[
    'UJENZI', 'MALIPO YA WAHUDUMU', 'MALIPO YA MATENGENEZO', 'MALIPO YA MANUNUZI',
  ];

  static const maxLength = 40;

  static String _kind(NameKind k) => k == NameKind.contribution ? 'contribution' : 'expenditure';

  /// Herufi kubwa, nafasi moja kati ya maneno, bila nafasi pembeni.
  static String normalize(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  static List<String> _merge(List<List<String>> groups) {
    final seen = <String>{};
    final out = <String>[];
    for (final g in groups) {
      for (final n in g) {
        final v = normalize(n);
        if (v.isNotEmpty && seen.add(v)) out.add(v);
      }
    }
    return out;
  }

  static Future<List<String>> contributions() async => _merge([
        contributionDefaults,
        await AppDb.instance.customNames(_kind(NameKind.contribution)),
        await AppDb.instance.usedContributionNames(),
      ]);

  static Future<List<String>> expenditures() async => _merge([
        expenditureDefaults,
        await AppDb.instance.customNames(_kind(NameKind.expenditure)),
        await AppDb.instance.usedExpenditureNames(),
      ]);

  static Future<List<String>> forKind(NameKind k) => k == NameKind.contribution ? contributions() : expenditures();

  static const _palette = <Color>[
    Color(0xFF1478F6), Color(0xFF7138F5), Color(0xFF11BFA4), Color(0xFFFFA914),
    Color(0xFF8D6E63), Color(0xFF546E7A), Color(0xFF00897B), Color(0xFFE0457B),
    Color(0xFF3F51B5), Color(0xFF6D9E1F),
  ];

  /// Rangi thabiti kwa jina lolote (jina lilelile hupata rangi ileile).
  static Color colorFor(String name) {
    var h = 0;
    for (final u in normalize(name).codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  /// Inarudisha ufunguo wa ujumbe wa kosa (kwa tr()) au null kama jina ni sahihi.
  static String? validate(String raw) {
    final v = normalize(raw);
    if (v.length < 2) return 'name_too_short';
    if (v.length > maxLength) return 'name_too_long';
    if (!RegExp(r'^[A-Z0-9 .,&()/\-]+$').hasMatch(v)) return 'name_invalid_chars';
    return null;
  }

  /// Inahifadhi jina jipya (kama halipo) na kurudisha jina lililosanifishwa.
  static Future<String> add(NameKind kind, String raw) async {
    final v = normalize(raw);
    final existing = await forKind(kind);
    if (!existing.contains(v)) await AppDb.instance.addCustomName(_kind(kind), v);
    return v;
  }
}
