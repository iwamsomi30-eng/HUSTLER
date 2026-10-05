
import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

enum ContributionKind { fungu, other }

class ContributionRow {
  String donorName = '';
  String envelopeNo = '';
  String contact = '';
  String amount = '';
  String nameNo = '';

  ContributionRow();

  Map<String, Object?> toMap() => {
        'donorName': donorName.trim(),
        'envelopeNo': envelopeNo.trim(),
        'contact': contact.trim(),
        'amount': amount.trim(),
        'nameNo': nameNo.trim(),
      };
}

class ContributionInputPage extends StatefulWidget {
  const ContributionInputPage({super.key});

  @override
  State<ContributionInputPage> createState() => _ContributionInputPageState();
}

class _ContributionInputPageState extends State<ContributionInputPage> {
  DateTime _date = DateTime.now();
  final _otherName = TextEditingController();
  final _dateLabel = TextEditingController();
  ContributionKind _kind = ContributionKind.fungu;

  final List<ContributionRow> _funguI = [ContributionRow()];
  final List<ContributionRow> _funguII = [ContributionRow()];
  final List<ContributionRow> _otherI = [ContributionRow()];
  final List<ContributionRow> _otherII = [ContributionRow()];

  @override
  void initState() {
    super.initState();
    _syncDateLabel();
  }

  @override
  void dispose() {
    _otherName.dispose();
    _dateLabel.dispose();
    super.dispose();
  }

  void _syncDateLabel() {
    _dateLabel.text =
        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
  }

  String _money(double value) {
    final s = value.round().toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  double _sum(List<ContributionRow> rows) {
    return rows.fold<double>(
      0,
      (total, row) => total + (double.tryParse(row.amount.replaceAll(',', '')) ?? 0),
    );
  }

  String _receipt() {
    final now = DateTime.now();
    return 'RC-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${(now.microsecond ~/ 100).toString().padLeft(4, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: tr('select_service_date'),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _syncDateLabel();
      });
    }
  }

  Future<void> _saveFungu(int service, List<ContributionRow> rows) async {
    final valid = rows.where((r) => r.envelopeNo.trim().isNotEmpty || r.amount.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      _snack(tr('add_at_least_one'), error: true);
      return;
    }
    for (final row in valid) {
      final amount = double.tryParse(row.amount.replaceAll(',', '').trim());
      if (row.envelopeNo.trim().isEmpty || row.donorName.trim().isEmpty || amount == null || amount <= 0) {
        _snack(tr('fungu_row_invalid'), error: true);
        return;
      }
    }

    try {
      final batchId = await AppDb.instance.saveFunguBatch(
        date: _date.toIso8601String(),
        service: service,
        title: 'Fungu',
        rows: [
          for (final row in valid)
            {
              'envelopeNo': row.envelopeNo.trim(),
              'donorName': row.donorName.trim(),
              'contact': row.contact.trim().isEmpty ? null : row.contact.trim(),
              'amount': double.parse(row.amount.replaceAll(',', '')),
              'receiptNo': _receipt(),
            },
        ],
      );
      await AppDb.instance.audit(
        'CONTRIBUTION_FUNGU_SAVED',
        'batch=$batchId; service=$service; rows=${valid.length}; total=${_sum(valid)}',
      );

      setState(() {
        rows
          ..clear()
          ..add(ContributionRow());
      });
      _snack('${tr('saved_successfully')}  ${_money(_sum(valid))} TZS');
    } catch (_) {
      _snack(tr('save_failed'), error: true);
    }
  }

  Future<void> _saveOther(int service, List<ContributionRow> rows) async {
    final title = _otherName.text.trim();
    if (title.isEmpty) {
      _snack(tr('other_name_required'), error: true);
      return;
    }
    final valid = rows.where((r) => r.donorName.trim().isNotEmpty || r.amount.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      _snack(tr('add_at_least_one'), error: true);
      return;
    }
    for (final row in valid) {
      final amount = double.tryParse(row.amount.replaceAll(',', '').trim());
      if (row.donorName.trim().isEmpty || amount == null || amount <= 0) {
        _snack(tr('other_row_invalid'), error: true);
        return;
      }
    }

    try {
      final batchId = await AppDb.instance.saveOtherBatch(
        date: _date.toIso8601String(),
        service: service,
        title: title,
        rows: [
          for (final row in valid)
            {
              'contributionName': title,
              'donorName': row.donorName.trim(),
              'contact': row.contact.trim().isEmpty ? null : row.contact.trim(),
              'amount': double.parse(row.amount.replaceAll(',', '')),
              'receiptNo': _receipt(),
            },
        ],
      );
      await AppDb.instance.audit(
        'CONTRIBUTION_OTHER_SAVED',
        'batch=$batchId; service=$service; title=$title; rows=${valid.length}; total=${_sum(valid)}',
      );

      setState(() {
        rows
          ..clear()
          ..add(ContributionRow());
      });
      _snack('${tr('saved_successfully')}  ${_money(_sum(valid))} TZS');
    } catch (_) {
      _snack(tr('save_failed'), error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(error ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Colors.red.shade700 : C.teal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pageIntro(),
                  const SizedBox(height: 16),
                  _dateAndMode(),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _kind == ContributionKind.fungu
                        ? _funguSection()
                        : _otherSection(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pageIntro() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [C.navy, C.navyDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: C.navy.withOpacity(.12),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: C.teal.withOpacity(.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('contribution_input_title'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(tr('contribution_input_subtitle'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 650)
            _pill(Icons.lock_outline, tr('offline_secure')),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: C.gold),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _dateAndMode() {
    return _card(
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 720;
          final date = TextField(
            controller: _dateLabel,
            readOnly: true,
            onTap: _pickDate,
            decoration: _input(tr('service_date'), Icons.calendar_month_outlined)
                .copyWith(suffixIcon: IconButton(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 19),
                )),
          );
          final kind = SegmentedButton<ContributionKind>(
              segments: [
                ButtonSegment(
                  value: ContributionKind.fungu,
                  icon: const Icon(Icons.markunread_mailbox_outlined),
                  label: Text(tr('fungu')),
                ),
                ButtonSegment(
                  value: ContributionKind.other,
                  icon: const Icon(Icons.people_alt_outlined),
                  label: Text(tr('other_contributions')),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                date,
                const SizedBox(height: 12),
                kind,
              ],
            );
          }
          return Row(children: [Expanded(child: date), const SizedBox(width: 14), Expanded(child: kind)]);
        },
      ),
    );
  }

  Widget _funguSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          icon: Icons.markunread_mailbox_outlined,
          title: tr('fungu'),
          subtitle: tr('fungu_description'),
        ),
        const SizedBox(height: 12),
        _serviceTable(
          service: 1,
          title: tr('ibada_one'),
          rows: _funguI,
          onAdd: () => setState(() => _funguI.add(ContributionRow())),
          onSave: () => _saveFungu(1, _funguI),
          fungu: true,
        ),
        const SizedBox(height: 14),
        _serviceTable(
          service: 2,
          title: tr('ibada_two'),
          rows: _funguII,
          onAdd: () => setState(() => _funguII.add(ContributionRow())),
          onSave: () => _saveFungu(2, _funguII),
          fungu: true,
        ),
      ],
    );
  }

  Widget _otherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          icon: Icons.groups_2_outlined,
          title: tr('other_contributions'),
          subtitle: tr('other_contributions_description'),
        ),
        const SizedBox(height: 12),
        _card(
          child: TextField(
            controller: _otherName,
            decoration: _input(tr('contribution_name'), Icons.label_outline),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 12),
        _serviceTable(
          service: 1,
          title: tr('ibada_one'),
          rows: _otherI,
          onAdd: () => setState(() => _otherI.add(ContributionRow())),
          onSave: () => _saveOther(1, _otherI),
        ),
        const SizedBox(height: 14),
        _serviceTable(
          service: 2,
          title: tr('ibada_two'),
          rows: _otherII,
          onAdd: () => setState(() => _otherII.add(ContributionRow())),
          onSave: () => _saveOther(2, _otherII),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: C.teal.withOpacity(.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: C.teal, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: C.navy, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: C.muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _serviceTable({
    required int service,
    required String title,
    required List<ContributionRow> rows,
    required VoidCallback onAdd,
    required VoidCallback onSave,
    bool fungu = false,
  }) {
    final total = _sum(rows);
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF7FAFE), Colors.white],
              ),
              border: Border(bottom: BorderSide(color: C.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: service == 1 ? C.blue.withOpacity(.1) : C.purple.withOpacity(.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('$service',
                      style: TextStyle(
                          color: service == 1 ? C.blue : C.purple,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: C.navy, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                Text('${rows.length} ${tr('rows')}',
                    style: const TextStyle(color: C.muted, fontSize: 11.5)),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 850;
              if (wide) {
                return _wideGrid(rows, fungu);
              }
              return _mobileRows(rows, fungu);
            },
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFBFCFE),
              border: Border(top: BorderSide(color: C.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('${tr('total')}: ${_money(total)} TZS',
                      style: const TextStyle(
                          color: C.navy, fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('add_row')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.navy,
                    side: const BorderSide(color: C.border),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(tr('save')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideGrid(List<ContributionRow> rows, bool fungu) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
              color: C.navy.withOpacity(.045),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _head('#', 42),
                if (fungu) ...[
                  _head(tr('envelope_no'), 135),
                  _head(tr('donor_name'), 210),
                ] else
                  _head(tr('donor_name'), 250),
                _head(tr('amount'), 150),
                _head(tr('contact'), 170),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...rows.asMap().entries.map((e) => _rowEditor(e.key, e.value, fungu, rows)),
        ],
      ),
    );
  }

  Widget _rowEditor(
      int index, ContributionRow row, bool fungu, List<ContributionRow> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text('${index + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: C.muted, fontWeight: FontWeight.w700)),
            ),
          ),
          if (fungu)
            SizedBox(
              width: 135,
              child: _compactField(
                initial: row.envelopeNo,
                hint: '001',
                onChanged: (v) => row.envelopeNo = v,
              ),
            ),
          const SizedBox(width: 6),
          Expanded(
            flex: fungu ? 3 : 4,
            child: _compactField(
              initial: row.donorName,
              hint: tr('name'),
              onChanged: (v) => row.donorName = v,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 150,
            child: _compactField(
              initial: row.amount,
              hint: '0',
              number: true,
              onChanged: (v) => row.amount = v,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 170,
            child: _compactField(
              initial: row.contact,
              hint: '07xx xxx xxx',
              number: true,
              onChanged: (v) => row.contact = v,
            ),
          ),
          IconButton(
            tooltip: tr('remove_row'),
            onPressed: rows.length == 1
                ? null
                : () => setState(() => rows.removeAt(index)),
            icon: const Icon(Icons.delete_outline, color: C.muted),
          ),
        ],
      ),
    );
  }

  Widget _mobileRows(List<ContributionRow> rows, bool fungu) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final row = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFCFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${tr('row')} ${e.key + 1}',
                    style: const TextStyle(color: C.navy, fontWeight: FontWeight.w800)),
                const SizedBox(height: 9),
                if (fungu) ...[
                  _field(
                    label: tr('envelope_no'),
                    initial: row.envelopeNo,
                    onChanged: (v) => row.envelopeNo = v,
                  ),
                  const SizedBox(height: 8),
                ],
                _field(
                  label: tr('donor_name'),
                  initial: row.donorName,
                  onChanged: (v) => row.donorName = v,
                ),
                const SizedBox(height: 8),
                _field(
                  label: tr('amount'),
                  initial: row.amount,
                  number: true,
                  onChanged: (v) => row.amount = v,
                ),
                const SizedBox(height: 8),
                _field(
                  label: tr('contact'),
                  initial: row.contact,
                  number: true,
                  onChanged: (v) => row.contact = v,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _head(String text, double width) => SizedBox(
        width: width,
        child: Text(text,
            style: const TextStyle(
                color: C.muted, fontSize: 11, fontWeight: FontWeight.w800)),
      );

  Widget _field({
    required String label,
    String? initial,
    bool number = false,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: initial ?? '',
      keyboardType: number ? TextInputType.phone : TextInputType.text,
      onChanged: onChanged,
      decoration: _input(label, null),
    );
  }

  Widget _compactField({
    String? initial,
    required String hint,
    bool number = false,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: initial ?? '',
      keyboardType: number ? TextInputType.phone : TextInputType.text,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: C.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: C.muted, fontSize: 12),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: C.border),
        ),
      ),
    );
  }

  InputDecoration _input(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 19),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
        boxShadow: [
          BoxShadow(
            color: C.navy.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
