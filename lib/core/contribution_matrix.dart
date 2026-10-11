/// Mantiki ya jedwali la watoaji kwa miezi na wiki (Rekodi za Michango).
///
/// Wiki ya mwezi: siku 1-7 = wiki 1, 8-14 = wiki 2, 15-21 = wiki 3,
/// 22-28 = wiki 4, na siku 29 na kuendelea = wiki 5.
int weekOfMonth(DateTime d) {
  final w = ((d.day - 1) ~/ 7) + 1;
  return w > 5 ? 5 : w;
}

class MatrixCell {
  double amount = 0;
  int count = 0;
  final Set<String> names = <String>{};
}

class DonorEntry {
  final DateTime date;
  final String contributionName;
  final double amount;
  final String receiptNo;
  final int service;
  const DonorEntry({
    required this.date,
    required this.contributionName,
    required this.amount,
    required this.receiptNo,
    required this.service,
  });
}

class DonorRecord {
  final String key;
  final bool isFungu;
  final String idNo;
  String name = '';
  String contact = '';
  String sex = '';
  DateTime firstDate;

  /// Michango yote ya mtoaji (bila kuzingatia kichujio cha tarehe).
  final List<DonorEntry> entries = [];

  /// Seli za jedwali: ni michango iliyo ndani ya kipindi kilichochaguliwa tu.
  final Map<String, MatrixCell> cells = {};

  DonorRecord({
    required this.key,
    required this.isFungu,
    required this.idNo,
    required this.firstDate,
  });

  double get total => entries.fold<double>(0, (s, e) => s + e.amount);

  MatrixCell? cell(int year, int month, int week) => cells['$year-$month-$week'];

  double monthTotal(int year, int month) {
    var t = 0.0;
    for (var w = 1; w <= 5; w++) {
      t += cell(year, month, w)?.amount ?? 0;
    }
    return t;
  }

  double yearTotal(int year) {
    var t = 0.0;
    for (var m = 1; m <= 12; m++) {
      t += monthTotal(year, m);
    }
    return t;
  }

  /// Jumla ya michango kwa kila aina ya mchango (FUNGU, INJILI, ...).
  Map<String, double> totalsByName() {
    final out = <String, double>{};
    for (final e in entries) {
      out[e.contributionName] = (out[e.contributionName] ?? 0) + e.amount;
    }
    return out;
  }
}

class ContributionMatrix {
  final List<DonorRecord> donors;
  final List<int> years;
  const ContributionMatrix(this.donors, this.years);

  static int _naturalCompare(String a, String b) {
    final x = int.tryParse(a);
    final y = int.tryParse(b);
    if (x != null && y != null) return x.compareTo(y);
    return a.compareTo(b);
  }

  /// [ledger] ni mistari yote ya michango (tazama AppDb.getContributionLedger).
  /// [from]/[to] zinabana michango inayoonekana kwenye seli; mtoaji
  /// anaendelea kuonekana hata kama hakutoa ndani ya kipindi (seli tupu),
  /// mradi alisajiliwa kabla ya mwisho wa kipindi.
  static ContributionMatrix build(
    List<Map<String, Object?>> ledger, {
    String search = '',
    DateTime? from,
    DateTime? to,
  }) {
    final start = from == null ? null : DateTime(from.year, from.month, from.day);
    final endExclusive = to == null ? null : DateTime(to.year, to.month, to.day + 1);
    final byKey = <String, DonorRecord>{};
    final years = <int>{};

    for (final r in ledger) {
      final date = DateTime.tryParse('${r['date'] ?? ''}');
      if (date == null) continue;
      final isFungu = r['type'] == 'FUNGU';
      final idNo = '${r['id_no'] ?? ''}'.trim();
      final donorName = '${r['donor_name'] ?? ''}'.trim();
      final key = '${isFungu ? 'F' : 'O'}|${idNo.isNotEmpty ? idNo : donorName}';
      final d = byKey.putIfAbsent(
        key,
        () => DonorRecord(key: key, isFungu: isFungu, idNo: idNo, firstDate: date),
      );
      if (date.isBefore(d.firstDate)) d.firstDate = date;
      // Ledger imepangwa kwa tarehe inayopanda, kwa hiyo thamani ya mwisho isiyo tupu inashinda.
      if (donorName.isNotEmpty) d.name = donorName;
      final contact = '${r['contact'] ?? ''}'.trim();
      if (contact.isNotEmpty) d.contact = contact;
      final sex = '${r['sex'] ?? ''}'.trim();
      if (sex.isNotEmpty) d.sex = sex;

      final amount = (r['amount'] as num?)?.toDouble() ?? 0;
      final cname = '${r['contribution_name'] ?? ''}'.trim();
      d.entries.add(DonorEntry(
        date: date,
        contributionName: cname.isEmpty ? (isFungu ? 'FUNGU' : '—') : cname,
        amount: amount,
        receiptNo: '${r['receipt_no'] ?? ''}',
        service: (r['service'] as num?)?.toInt() ?? 1,
      ));

      final inRange = (start == null || !date.isBefore(start)) &&
          (endExclusive == null || date.isBefore(endExclusive));
      if (inRange) {
        years.add(date.year);
        final cell = d.cells.putIfAbsent('${date.year}-${date.month}-${weekOfMonth(date)}', () => MatrixCell());
        cell.amount += amount;
        cell.count += 1;
        cell.names.add(cname.isEmpty ? (isFungu ? 'FUNGU' : '—') : cname);
      }
    }

    if (from != null) years.add(from.year);
    if (to != null) years.add(to.year);
    if (from != null && to != null && to.year >= from.year && to.year - from.year < 50) {
      for (var y = from.year; y <= to.year; y++) {
        years.add(y);
      }
    }
    if (years.isEmpty) years.add(DateTime.now().year);

    final q = search.trim().toLowerCase();
    final donors = byKey.values.where((d) {
      if (endExclusive != null && !d.firstDate.isBefore(endExclusive)) return false;
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          d.idNo.toLowerCase().contains(q) ||
          d.contact.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        if (a.isFungu != b.isFungu) return a.isFungu ? -1 : 1;
        final c = _naturalCompare(a.idNo, b.idNo);
        if (c != 0) return c;
        return a.firstDate.compareTo(b.firstDate);
      });

    return ContributionMatrix(donors, years.toList()..sort());
  }
}
