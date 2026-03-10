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
      final now = DateTime.now();
      loan.updatedAt = now;

      // Bootstrap a first disbursement for non-ledger legacy input.
      if (loan.disbursements.isEmpty && loan.principalAmount > 0) {
        loan.disbursements = [
          LoanDisbursement()
            ..amount = loan.principalAmount
            ..date = loan.createdAt
            ..dueDate = loan.dueDate
            ..note = loan.title,
        ];
      }

      _syncLegacyDueDate(loan);
      return _isar.loanModels.put(loan);
    });
  }

  Future<void> update(LoanModel loan) async {
    await _isar.writeTxn(() async {
      loan.updatedAt = DateTime.now();
      _syncLegacyDueDate(loan);
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

  Future<List<String>> getDistinctPersonNames() async {
    final loans = await getAll();
    final namesByKey = <String, String>{};
    for (final loan in loans) {
      final raw = loan.personName.trim();
      if (raw.isEmpty) continue;
      namesByKey.putIfAbsent(_normalizeName(raw), () => raw);
    }
    final names = namesByKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<LoanModel?> findActiveLedger(String personName, int type) async {
    final normalized = _normalizeName(personName);
    final activeByType = await getByType(type, includeClosed: false);
    for (final loan in activeByType) {
      if (_normalizeName(loan.personName) == normalized) {
        return loan;
      }
    }
    return null;
  }

  // -- LEDGER ACTIONS -------------------------------------------------------

  Future<void> addDisbursement(
    int loanId,
    double amount, {
    DateTime? date,
    DateTime? dueDate,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Disbursement amount must be greater than zero.');
    }

    await _isar.writeTxn(() async {
      final loan = await _isar.loanModels.get(loanId);
      if (loan == null) {
        throw StateError('Loan not found.');
      }

      final disbursement = LoanDisbursement()
        ..amount = amount
        ..date = date ?? DateTime.now()
        ..dueDate = dueDate
        ..note = note;

      loan.disbursements = [...loan.disbursements, disbursement];
      loan.principalAmount += amount;
      loan.isClosed = false;
      loan.updatedAt = DateTime.now();

      _syncLegacyDueDate(loan);
      await _isar.loanModels.put(loan);
    });
  }

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
      loan.paidAmount = (loan.paidAmount + amount).clamp(
        0.0,
        loan.principalAmount,
      );
      loan.updatedAt = DateTime.now();

      if (loan.outstandingAmount <= 0.01) {
        loan.paidAmount = loan.principalAmount;
        loan.isClosed = true;
      }

      _syncLegacyDueDate(loan);
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
      _syncLegacyDueDate(loan);
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
      _syncLegacyDueDate(loan);
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
    final loans = await getActive();
    return loans.where((loan) => loan.isOverdue).toList()..sort((a, b) {
      final aDue = a.nextDueDate;
      final bDue = b.nextDueDate;
      if (aDue == null && bDue == null) return 0;
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      return aDue.compareTo(bDue);
    });
  }

  // -- REAL-TIME STREAM -----------------------------------------------------

  Stream<void> watchAll() {
    return _isar.loanModels.watchLazy();
  }

  // -- INTERNAL -------------------------------------------------------------

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _syncLegacyDueDate(LoanModel loan) {
    // Keep top-level dueDate aligned for existing queries/indexes.
    loan.dueDate = loan.nextDueDate;
  }
}
