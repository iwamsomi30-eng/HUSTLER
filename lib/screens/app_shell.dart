import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/lang_toggle.dart';
import 'dashboard_page.dart';
import 'contribution_input_page.dart';
import 'contribution_records_page.dart';
import 'expenditure_input_page.dart';
import 'expenditure_records_page.dart';
import 'expenditure_summary_page.dart';
import 'balance_page.dart';

class _Nav {
  final IconData icon;
  final String key;
  final int stage; // hatua ambayo ukurasa utajengwa
  const _Nav(this.icon, this.key, this.stage);
}

const _navMain = [
  _Nav(Icons.home_rounded, 'nav_dashboard', 8),
  _Nav(Icons.person_add_alt_1, 'nav_michango_input', 2),
  _Nav(Icons.receipt_long, 'nav_michango_records', 3),
  _Nav(Icons.request_quote, 'nav_matumizi_input', 4),
  _Nav(Icons.description_outlined, 'nav_matumizi_records', 5),
  _Nav(Icons.bar_chart_rounded, 'nav_muhtasari', 6),
  _Nav(Icons.account_balance_wallet, 'nav_salio', 7),
];
const _navBottom = [
  _Nav(Icons.settings, 'nav_settings', 10),
  _Nav(Icons.info_outline, 'nav_about', 0),
];

class AppShell extends StatefulWidget {
  final VoidCallback onLogout;
  const AppShell({super.key, required this.onLogout});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _key = GlobalKey<ScaffoldState>();
  int _index = 0; // 0..6 main, 7 settings, 8 about

  _Nav get _cur => _index < 7 ? _navMain[_index] : _navBottom[_index - 7];

  void _select(int i, bool wide) {
    setState(() => _index = i);
    if (!wide) _key.currentState?.closeDrawer();
  }

  Widget _page() {
    if (_index == 0) return const DashboardPage();
    if (_index == 1) return const ContributionInputPage();
    if (_index == 2) return const ContributionRecordsPage();
    if (_index == 3) return const ExpenditureInputPage();
    if (_index == 4) return const ExpenditureRecordsPage();
    if (_index == 5) return const ExpenditureSummaryPage();
    if (_index == 6) return const BalancePage();
    if (_index == 8) return const _AboutPage();
    return _ComingSoon(stage: _cur.stage);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) {
        final wide = MediaQuery.of(context).size.width >= 900;
        final sidebar = _Sidebar(
          index: _index,
          onSelect: (i) => _select(i, wide),
          onLogout: widget.onLogout,
        );
        return Scaffold(
          key: _key,
          drawer: wide ? null : Drawer(width: 260, child: sidebar),
          body: Row(
            children: [
              if (wide) SizedBox(width: 250, child: sidebar),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      title: _index == 0 ? tr('dash_title') : tr(_cur.key),
                      subtitle: _index == 0 ? tr('dash_sub') : null,
                      showMenu: !wide,
                      onMenu: () => _key.currentState?.openDrawer(),
                    ),
                    Expanded(child: _page()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  const _Sidebar(
      {required this.index, required this.onSelect, required this.onLogout});

  Widget _item(_Nav n, int i) {
    final sel = index == i;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: sel ? C.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelect(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(n.icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(tr(n.key),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Solid opaque color is intentionally used instead of a gradient here:
    // it renders consistently on Flutter Windows and prevents white/transparent
    // sidebar backgrounds on some desktop graphics drivers.
    return Container(
      color: C.navy,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Row(
                children: [
                  const Icon(Icons.church, color: C.gold, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tr('app_name_short'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            height: 1.25)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < _navMain.length; i++)
                    _item(_navMain[i], i),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 6),
            for (var i = 0; i < _navBottom.length; i++)
              _item(_navBottom[i], 7 + i),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onLogout,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    const Icon(Icons.logout, color: Colors.white70, size: 20),
                    const SizedBox(width: 12),
                    Text(tr('logout'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(tr('motto'),
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showMenu;
  final VoidCallback onMenu;
  const _TopBar(
      {required this.title,
      this.subtitle,
      required this.showMenu,
      required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 600;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showMenu)
              IconButton(
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu, color: C.navy)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: C.navy)),
                  if (subtitle != null && !narrow)
                    Text(subtitle!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: C.muted)),
                ],
              ),
            ),
            const LangToggle(),
            if (!narrow) ...[
              const SizedBox(width: 12),
              const Icon(Icons.notifications_none, color: C.navy),
              const SizedBox(width: 12),
              const CircleAvatar(
                  radius: 18,
                  backgroundColor: C.navy,
                  child: Icon(Icons.person, color: Colors.white, size: 20)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('admin'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: C.text)),
                  Text(tr('admin_role'),
                      style: const TextStyle(fontSize: 11, color: C.muted)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final int stage;
  const _ComingSoon({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 44, color: C.gold),
            const SizedBox(height: 12),
            Text('${tr('coming_soon')} $stage',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: C.text)),
          ],
        ),
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.church, size: 50, color: C.gold),
            const SizedBox(height: 10),
            Text(tr('app_name'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: C.navy)),
            const SizedBox(height: 8),
            Text(tr('about_text'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: C.muted)),
            const SizedBox(height: 12),
            Text('${tr('version')} 0.1.0 (Stage 1)',
                style: const TextStyle(color: C.text)),
          ],
        ),
      ),
    );
  }
}
