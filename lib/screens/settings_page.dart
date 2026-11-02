import 'package:flutter/material.dart';
import '../core/auth.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  Map<String, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await AppDb.instance.getBusinessDataCounts();
      if (mounted) setState(() {
        _counts = counts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _contributionRows =>
      (_counts['fungu_contributions'] ?? 0) +
      (_counts['other_contributions'] ?? 0);

  int get _expenseRows => _counts['expenditure_entries'] ?? 0;

  Future<void> _changePin() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(tr('change_pin')),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('change_pin_sub'),
                    style: const TextStyle(color: C.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: current,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('current_pin')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: next,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('new_pin')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirm,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('pin_confirm')),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: Text(tr('cancel')),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final oldPin = current.text.trim();
                        final newPin = next.text.trim();
                        final confirmPin = confirm.text.trim();
                        if (newPin.length < 4 ||
                            newPin.length > 8 ||
                            !RegExp(r'^\d+$').hasMatch(newPin)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('pin_short')),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }
                        if (newPin != confirmPin) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('pin_mismatch')),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        final valid = await Auth.verify(oldPin);
                        if (!valid) {
                          setDialogState(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(tr('pin_wrong')),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                          return;
                        }
                        await Auth.setPin(newPin);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('pin_changed')),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: C.teal,
                            ),
                          );
                        }
                      },
                child: Text(tr('save_pin')),
              ),
            ],
          ),
        ),
      );
    } finally {
      current.dispose();
      next.dispose();
      confirm.dispose();
    }
  }

  Future<void> _deleteAllData() async {
    final pin = TextEditingController();
    try {
      final firstConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('delete_all_title'))),
            ],
          ),
          content: Text(tr('delete_all_warning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('continue')),
            ),
          ],
        ),
      );
      if (firstConfirm != true || !mounted) return;

      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(tr('confirm_with_pin')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('delete_all_pin_sub'),
                style: const TextStyle(color: C.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pin,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('current_pin')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel')),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_forever),
              label: Text(tr('delete_all')),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;

      final valid = await Auth.verify(pin.text.trim());
      if (!valid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('pin_wrong')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      final counts = await AppDb.instance.deleteAllBusinessData();
      await _loadCounts();
      if (!mounted) return;
      final total = (counts['fungu_contributions'] ?? 0) +
          (counts['other_contributions'] ?? 0) +
          (counts['expenditure_entries'] ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('delete_all_success')} $total'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.teal,
        ),
      );
    } finally {
      pin.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _loadCounts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            pagePad(context),
            18,
            pagePad(context),
            36,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 16),
                  _securityCard(),
                  const SizedBox(height: 14),
                  _dataCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: C.navy,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: C.navy.withOpacity(.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('settings_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('settings_subtitle'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _securityCard() => _section(
        icon: Icons.lock_outline,
        title: tr('security_settings'),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEAF7F4),
            child: Icon(Icons.password, color: C.teal),
          ),
          title: Text(
            tr('change_pin'),
            style: const TextStyle(fontWeight: FontWeight.w800, color: C.text),
          ),
          subtitle: Text(tr('change_pin_sub')),
          trailing: const Icon(Icons.chevron_right, color: C.muted),
          onTap: _changePin,
        ),
      );

  Widget _dataCard() => _section(
        icon: Icons.storage_outlined,
        title: tr('data_management'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              const LinearProgressIndicator(minHeight: 3)
            else
              LayoutBuilder(
                builder: (context, box) {
                  final compact = box.maxWidth < 560;
                  final cards = [
                    _countCard(
                      tr('settings_contribution_data'),
                      _contributionRows,
                      Icons.volunteer_activism_outlined,
                    ),
                    _countCard(
                      tr('settings_expenditure_data'),
                      _expenseRows,
                      Icons.payments_outlined,
                    ),
                  ];
                  return compact
                      ? Column(
                          children: [
                            for (final card in cards)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: card,
                              ),
                          ],
                        )
                      : Row(
                          children: [
                            for (var i = 0; i < cards.length; i++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i == cards.length - 1 ? 0 : 10,
                                  ),
                                  child: cards[i],
                                ),
                              ),
                          ],
                        );
                },
              ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.gold.withOpacity(.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: C.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('delete_all_note'),
                      style: const TextStyle(
                        color: C.text,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: _deleteAllData,
                icon: const Icon(Icons.delete_forever),
                label: Text(tr('delete_all')),
              ),
            ),
          ],
        ),
      );

  Widget _countCard(String label, int count, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: C.navy.withOpacity(.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: C.navy),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: C.muted, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: C.navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: C.navy),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: C.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            child,
          ],
        ),
      );
}
