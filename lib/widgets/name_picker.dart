import 'package:flutter/material.dart';
import '../core/catalog.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// Sanduku la kuchagua jina (mchango au matumizi) lenye chaguo la mwisho
/// "Ongeza jina jipya" ambalo hufungua dirisha la kuandika jina.
class NamePicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> items;
  final String? value;
  final ValueChanged<String> onChanged;

  /// Inaitwa na jina jipya lililothibitishwa (herufi kubwa). Mzazi analihifadhi,
  /// anapakia orodha upya na kulichagua.
  final Future<void> Function(String name) onAdd;

  const NamePicker({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.onAdd,
  });

  static const _addKey = '__add_new_name__';

  Future<String?> _askName(BuildContext context) {
    final ctrl = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(tr('name_new_title')),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: NameCatalog.maxLength,
              decoration: InputDecoration(
                labelText: label,
                hintText: tr('name_new_hint'),
                errorText: error == null ? null : tr(error!),
              ),
              onSubmitted: (_) {
                final e = NameCatalog.validate(ctrl.text);
                if (e != null) {
                  setLocal(() => error = e);
                } else {
                  Navigator.pop(ctx, NameCatalog.normalize(ctrl.text));
                }
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
            FilledButton(
              onPressed: () {
                final e = NameCatalog.validate(ctrl.text);
                if (e != null) {
                  setLocal(() => error = e);
                } else {
                  Navigator.pop(ctx, NameCatalog.normalize(ctrl.text));
                }
              },
              child: Text(tr('name_add_button')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = items.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('${current ?? '-'}|${items.length}'),
      value: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
      items: [
        for (final i in items) DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis)),
        DropdownMenuItem(
          value: _addKey,
          child: Row(children: [
            const Icon(Icons.add_circle_outline, size: 19, color: C.teal),
            const SizedBox(width: 8),
            Flexible(
              child: Text(tr('name_add_new'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.teal, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ],
      onChanged: (v) async {
        if (v == null) return;
        if (v == _addKey) {
          final name = await _askName(context);
          if (name != null) await onAdd(name);
        } else {
          onChanged(v);
        }
      },
    );
  }
}
