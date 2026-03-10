import 'package:isar/isar.dart';

import '../../domain/models/loan_model.dart';
import '../local/database_service.dart';

/// Repository for managing lendings and borrowings.
class LoanRepository {
  final DatabaseService _db;

  LoanRepository(this._db);

  Isar get _isar => _db.isar;

  // -- CRUD -----------------------------------------------------------------

  Future<int> add(LoanModel loan) async {
    return _isar.writeTxn(() async {
      loan.updatedAt = DateTime.now();
      return _isar.loanModels.put(loan);
    });
  }

  Future<void> update(LoanModel loan) async {
    await _isar.writeTxn(() async {
      loan.updatedAt = DateTime.now();
      await _isar.loanModels.put(loan);
    });
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.loanModels.delete(id);
    });
  }

  Future<LoanModel?> getById(int id) async {
    return _isar.loanModels.get(id);
  }

  Future<List<LoanModel>> getAll() async {
    return _isar.loanModels.where().sortByCreatedAtDesc().findAll();
  }

  Future<List<LoanModel>> getActive() async {
    return _isar.loanModels
        .where()
        .isClosedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<List<LoanModel>> getClosed() async {
    return _isar.loanModels
        .where()
        .isClosedEqualTo(true)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  Future<List<LoanModel>> getByType(int type, {bool includeClosed = true}) {
    if (includeClosed) {
      return _isar.loanModels
          .where()
          .typeEqualTo(type)
          .sortByCreatedAtDesc()
          .findAll();
    }
    return _isar.loanModels
        .filter()
        .typeEqualTo(type)
        .and()
        .isClosedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  // -- LOAN ACTIONS ---------------------------------------------------------

  Future<void> addRepayment(
    int loanId,
    double amount, {
    DateTime? date,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Repayment amount must be greater than zero.');
    }

    await _isar.writeTxn(() async {
      final loan = await _isar.loanModels.get(loanId);
      if (loan == null) {
        throw StateError('Loan not found.');
      }

      final repayment = LoanRepayment()
        ..amount = amount
        ..date = date ?? DateTime.now()
        ..note = note;

      loan.repayments = [...loan.repayments, repayment];
      loan.paidAmount += amount;
      loan.updatedAt = DateTime.now();

      if (loan.outstandingAmount <= 0.01) {
        loan.paidAmount = loan.principalAmount;
        loan.isClosed = true;
      }

      await _isar.loanModels.put(loan);
    });
  }

  Future<void> closeLoan(int loanId) async {
    await _isar.writeTxn(() async {
      final loan = await _isar.loanModels.get(loanId);
      if (loan == null) return;

      loan.isClosed = true;
      if (loan.paidAmount < loan.principalAmount) {
        loan.paidAmount = loan.principalAmount;
      }
      loan.updatedAt = DateTime.now();
      await _isar.loanModels.put(loan);
    });
  }

  Future<void> reopenLoan(int loanId) async {
    await _isar.writeTxn(() async {
      final loan = await _isar.loanModels.get(loanId);
      if (loan == null) return;

      loan.isClosed = false;
      if (loan.paidAmount >= loan.principalAmount) {
        loan.paidAmount = (loan.principalAmount - 0.01).clamp(
          0.0,
          loan.principalAmount,
        );
      }
      loan.updatedAt = DateTime.now();
      await _isar.loanModels.put(loan);
    });
  }

  // -- AGGREGATES -----------------------------------------------------------

  Future<double> getTotalReceivable() async {
    final activeLendings = await getByType(0, includeClosed: false);
    return activeLendings.fold<double>(0, (sum, loan) {
      return sum + loan.outstandingAmount;
    });
  }

  Future<double> getTotalPayable() async {
    final activeBorrowings = await getByType(1, includeClosed: false);
    return activeBorrowings.fold<double>(0, (sum, loan) {
      return sum + loan.outstandingAmount;
    });
  }

  Future<List<LoanModel>> getOverdue() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final loans = await getActive();
    return loans
        .where(
          (loan) =>
              loan.dueDate != null &&
              DateTime(
                loan.dueDate!.year,
                loan.dueDate!.month,
                loan.dueDate!.day,
              ).isBefore(today) &&
              loan.outstandingAmount > 0.01,
        )
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  // -- REAL-TIME STREAM -----------------------------------------------------

  Stream<void> watchAll() {
    return _isar.loanModels.watchLazy();
  }
}
