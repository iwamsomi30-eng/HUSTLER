import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const StatCard(
      {super.key,
      required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
              radius: 24,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: C.text, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: C.navy)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashboard ya msingi (Hatua ya 1): muundo wa kadi nne. Data halisi inakuja Hatua ya 7.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth - 48;
      final cols = w >= 900 ? 4 : (w >= 520 ? 2 : 1);
      final cardW = (w - (cols - 1) * 14) / cols;
      Widget card(IconData i, Color col, String k) => SizedBox(
            width: cardW,
            child: StatCard(
                icon: i, color: col, label: tr(k), value: 'TZS 0'),
          );
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 14, runSpacing: 14, children: [
              card(Icons.savings, C.blue, 'makusanyo'),
              card(Icons.account_balance_wallet, C.gold, 'matumizi'),
              card(Icons.balance, C.teal, 'salio'),
              card(Icons.groups, C.purple, 'michango'),
            ]),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.bar_chart_rounded, size: 44, color: C.border),
                  const SizedBox(height: 8),
                  Text(tr('dash_empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: C.muted)),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
