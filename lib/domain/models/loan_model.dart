import 'dart:convert';

/// Embedded repayment record for a loan.
class LoanRepayment {
  double amount;
  DateTime date;
  String? note;

  LoanRepayment({this.amount = 0, DateTime? date, this.note})
      : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory LoanRepayment.fromJson(Map<String, dynamic> j) => LoanRepayment(
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String?,
      );

  static List<LoanRepayment> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => LoanRepayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<LoanRepayment> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}

/// Embedded disbursement record for a loan ledger.
class LoanDisbursement {
  double amount;
  DateTime date;
  DateTime? dueDate;
  String? note;

  LoanDisbursement({this.amount = 0, DateTime? date, this.dueDate, this.note})
      : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'date': date.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'note': note,
      };

  factory LoanDisbursement.fromJson(Map<String, dynamic> j) =>
      LoanDisbursement(
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        dueDate: j['dueDate'] != null
            ? DateTime.parse(j['dueDate'] as String)
            : null,
        note: j['note'] as String?,
      );

  static List<LoanDisbursement> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => LoanDisbursement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<LoanDisbursement> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}

enum LoanLedgerEntryType { disbursement, repayment }

/// Derived, non-persisted row for a merged chronological ledger view.
class LoanLedgerEntry {
  final LoanLedgerEntryType type;
  final double amount;
  final DateTime date;
  final DateTime? dueDate;
  final String? note;
  final double runningPrincipal;
  final double runningPaid;
  final double runningOutstanding;
  final int sourceIndex;

  const LoanLedgerEntry({
    required this.type,
    required this.amount,
    required this.date,
    required this.dueDate,
    required this.note,
    required this.runningPrincipal,
    required this.runningPaid,
    required this.runningOutstanding,
    required this.sourceIndex,
  });
}

/// Tracks money lent to or borrowed from a person.
class LoanModel {
  int id;

  /// 0 = lending (you gave money), 1 = borrowing (you received money)
  int type;

  String personName;
  String? title;
  double principalAmount;

  /// Total amount repaid/collected so far.
  double paidAmount;

  /// Optional annual interest percentage.
  double? interestRate;

  DateTime? dueDate;
  String? note;
  bool isClosed;
  DateTime createdAt;
  DateTime updatedAt;
  List<LoanDisbursement> disbursements;
  List<LoanRepayment> repayments;

  double get outstandingAmount =>
      (principalAmount - paidAmount).clamp(0.0, double.infinity).toDouble();

  double get progress => principalAmount > 0
      ? (paidAmount / principalAmount).clamp(0.0, 1.0).toDouble()
      : 0.0;

  bool get isOverdue => overdueAmount > 0.01;

  double get overdueAmount {
    if (isClosed || disbursements.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var remainingPaid = paidAmount;
    var overdue = 0.0;
    final sorted = [...disbursements]..sort((a, b) => a.date.compareTo(b.date));
    for (final item in sorted) {
      final covered = remainingPaid.clamp(0.0, item.amount).toDouble();
      remainingPaid = (remainingPaid - covered).clamp(0.0, double.infinity);
      final outstandingPart = (item.amount - covered).clamp(0.0, item.amount);
      final due = item.dueDate;
      if (due == null) continue;
      final dueDateOnly = DateTime(due.year, due.month, due.day);
      if (dueDateOnly.isBefore(today)) overdue += outstandingPart;
    }
    return overdue;
  }

  DateTime? get nextDueDate {
    if (disbursements.isEmpty || outstandingAmount <= 0.01) return dueDate;
    var remainingPaid = paidAmount;
    DateTime? nearest;
    final sorted = [...disbursements]..sort((a, b) => a.date.compareTo(b.date));
    for (final item in sorted) {
      final covered = remainingPaid.clamp(0.0, item.amount).toDouble();
      remainingPaid = (remainingPaid - covered).clamp(0.0, double.infinity);
      final outstandingPart = (item.amount - covered).clamp(0.0, item.amount);
      if (outstandingPart <= 0.01 || item.dueDate == null) continue;
      if (nearest == null || item.dueDate!.isBefore(nearest)) {
        nearest = item.dueDate;
      }
    }
    return nearest ?? dueDate;
  }

  List<LoanLedgerEntry> get timeline {
    final events = <({
      LoanLedgerEntryType type,
      double amount,
      DateTime date,
      DateTime? dueDate,
      String? note,
      int sourceIndex,
    })>[];

    for (var i = 0; i < disbursements.length; i++) {
      final d = disbursements[i];
      events.add((
        type: LoanLedgerEntryType.disbursement,
        amount: d.amount,
        date: d.date,
        dueDate: d.dueDate,
        note: d.note,
        sourceIndex: i,
      ));
    }
    for (var i = 0; i < repayments.length; i++) {
      final r = repayments[i];
      events.add((
        type: LoanLedgerEntryType.repayment,
        amount: r.amount,
        date: r.date,
        dueDate: null,
        note: r.note,
        sourceIndex: i,
      ));
    }
    events.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      if (a.type != b.type) {
        return a.type == LoanLedgerEntryType.disbursement ? -1 : 1;
      }
      return a.sourceIndex.compareTo(b.sourceIndex);
    });

    var runningPrincipal = 0.0;
    var runningPaid = 0.0;
    final result = <LoanLedgerEntry>[];
    for (final event in events) {
      if (event.type == LoanLedgerEntryType.disbursement) {
        runningPrincipal += event.amount;
      } else {
        runningPaid =
            (runningPaid + event.amount).clamp(0.0, runningPrincipal);
      }
      result.add(LoanLedgerEntry(
        type: event.type,
        amount: event.amount,
        date: event.date,
        dueDate: event.dueDate,
        note: event.note,
        sourceIndex: event.sourceIndex,
        runningPrincipal: runningPrincipal,
        runningPaid: runningPaid,
        runningOutstanding:
            (runningPrincipal - runningPaid).clamp(0.0, double.infinity),
      ));
    }
    return result;
  }

  LoanModel({
    this.id = 0,
    this.type = 0,
    this.personName = '',
    this.title,
    this.principalAmount = 0.0,
    this.paidAmount = 0.0,
    this.interestRate,
    this.dueDate,
    this.note,
    this.isClosed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<LoanDisbursement>? disbursements,
    List<LoanRepayment>? repayments,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        disbursements = disbursements ?? [],
        repayments = repayments ?? [];
}
