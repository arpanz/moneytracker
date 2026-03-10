import 'package:isar/isar.dart';

part 'loan_model.g.dart';

/// Embedded repayment record for a loan.
@embedded
class LoanRepayment {
  late double amount;
  late DateTime date;
  String? note;

  LoanRepayment() : amount = 0;
}

/// Embedded disbursement record for a loan ledger.
@embedded
class LoanDisbursement {
  late double amount;
  late DateTime date;
  DateTime? dueDate;
  String? note;

  LoanDisbursement() : amount = 0;
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
@collection
class LoanModel {
  Id id = Isar.autoIncrement;

  /// 0 = lending (you gave money), 1 = borrowing (you received money)
  @Index()
  late int type;

  late String personName;

  String? title;

  late double principalAmount;

  /// Total amount repaid/collected so far.
  late double paidAmount;

  /// Optional annual interest percentage.
  double? interestRate;

  @Index()
  DateTime? dueDate;

  String? note;

  @Index()
  late bool isClosed;

  late DateTime createdAt;
  late DateTime updatedAt;

  late List<LoanDisbursement> disbursements;
  late List<LoanRepayment> repayments;

  @ignore
  double get outstandingAmount =>
      (principalAmount - paidAmount).clamp(0.0, double.infinity).toDouble();

  @ignore
  double get progress => principalAmount > 0
      ? (paidAmount / principalAmount).clamp(0.0, 1.0).toDouble()
      : 0.0;

  @ignore
  bool get isOverdue {
    return overdueAmount > 0.01;
  }

  /// Amount past due, computed from outstanding allocations on disbursements.
  @ignore
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
      if (dueDateOnly.isBefore(today)) {
        overdue += outstandingPart;
      }
    }

    return overdue;
  }

  /// Nearest due date among disbursements that still have outstanding amount.
  @ignore
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

  /// Unified timeline of disbursements + repayments sorted chronologically.
  ///
  /// Running totals allow UI to render a true ledger history without
  /// duplicating relationships in persisted embedded objects.
  @ignore
  List<LoanLedgerEntry> get timeline {
    final events =
        <
          ({
            LoanLedgerEntryType type,
            double amount,
            DateTime date,
            DateTime? dueDate,
            String? note,
            int sourceIndex,
          })
        >[];

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
    final timeline = <LoanLedgerEntry>[];

    for (final event in events) {
      if (event.type == LoanLedgerEntryType.disbursement) {
        runningPrincipal += event.amount;
      } else {
        runningPaid = (runningPaid + event.amount).clamp(0.0, runningPrincipal);
      }

      timeline.add(
        LoanLedgerEntry(
          type: event.type,
          amount: event.amount,
          date: event.date,
          dueDate: event.dueDate,
          note: event.note,
          sourceIndex: event.sourceIndex,
          runningPrincipal: runningPrincipal,
          runningPaid: runningPaid,
          runningOutstanding: (runningPrincipal - runningPaid).clamp(
            0.0,
            double.infinity,
          ),
        ),
      );
    }

    return timeline;
  }

  LoanModel()
    : type = 0,
      paidAmount = 0.0,
      isClosed = false,
      disbursements = [],
      repayments = [],
      createdAt = DateTime.now(),
      updatedAt = DateTime.now();
}
