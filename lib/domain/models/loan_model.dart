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
    if (isClosed || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  LoanModel()
    : type = 0,
      paidAmount = 0.0,
      isClosed = false,
      repayments = [],
      createdAt = DateTime.now(),
      updatedAt = DateTime.now();
}
