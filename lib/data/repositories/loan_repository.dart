import 'package:drift/drift.dart';

import '../../domain/models/loan_model.dart';
import '../local/database_service.dart';

/// Repository for managing loans (lending and borrowing).
class LoanRepository {
  final DatabaseService _db;

  LoanRepository(this._db);

  AppDatabase get _d => _db.db;

  // ── Mapping ──────────────────────────────────────────────────────────────

  LoanModel _fromRow(Loan row) => LoanModel(
        id: row.id,
        type: row.type,
        personName: row.personName,
        title: row.title,
        principalAmount: row.principalAmount,
        paidAmount: row.paidAmount,
        interestRate: row.interestRate,
        dueDate: row.dueDate,
        note: row.note,
        isClosed: row.isClosed,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        disbursements: LoanDisbursement.listFromJson(row.disbursements),
        repayments: LoanRepayment.listFromJson(row.repayments),
      );

  LoansCompanion _toCompanion(LoanModel l) => LoansCompanion.insert(
        type: Value(l.type),
        personName: l.personName,
        title: Value(l.title),
        principalAmount: l.principalAmount,
        paidAmount: Value(l.paidAmount),
        interestRate: Value(l.interestRate),
        dueDate: Value(l.dueDate),
        note: Value(l.note),
        isClosed: Value(l.isClosed),
        createdAt: l.createdAt,
        updatedAt: l.updatedAt,
        disbursements: Value(LoanDisbursement.listToJson(l.disbursements)),
        repayments: Value(LoanRepayment.listToJson(l.repayments)),
      );

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<int> add(LoanModel loan) =>
      _d.into(_d.loans).insert(_toCompanion(loan));

  Future<void> update(LoanModel loan) async {
    await (_d.update(_d.loans)..where((l) => l.id.equals(loan.id)))
        .write(LoansCompanion(
      type: Value(loan.type),
      personName: Value(loan.personName),
      title: Value(loan.title),
      principalAmount: Value(loan.principalAmount),
      paidAmount: Value(loan.paidAmount),
      interestRate: Value(loan.interestRate),
      dueDate: Value(loan.dueDate),
      note: Value(loan.note),
      isClosed: Value(loan.isClosed),
      updatedAt: Value(loan.updatedAt),
      disbursements: Value(LoanDisbursement.listToJson(loan.disbursements)),
      repayments: Value(LoanRepayment.listToJson(loan.repayments)),
    ));
  }

  Future<void> delete(int id) async {
    await (_d.delete(_d.loans)..where((l) => l.id.equals(id))).go();
  }

  Future<LoanModel?> getById(int id) async {
    final row = await (_d.select(_d.loans)..where((l) => l.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<LoanModel>> getAll() async {
    final rows = await (_d.select(_d.loans)
          ..orderBy([(l) => OrderingTerm.desc(l.createdAt)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<LoanModel>> getByType(int type) async {
    final rows = await (_d.select(_d.loans)
          ..where((l) => l.type.equals(type) & l.isClosed.equals(false)))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<LoanModel>> getOpen() async {
    final rows = await (_d.select(_d.loans)
          ..where((l) => l.isClosed.equals(false)))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<void> addRepayment(
    int loanId,
    double amount, {
    DateTime? date,
    String? note,
  }) async {
    final loan = await getById(loanId);
    if (loan == null) return;
    final repayment = LoanRepayment(
      amount: amount,
      date: date ?? DateTime.now(),
      note: note,
    );
    final updated = [...loan.repayments, repayment];
    final newPaid = loan.paidAmount + amount;
    await (_d.update(_d.loans)..where((l) => l.id.equals(loanId))).write(
      LoansCompanion(
        paidAmount: Value(newPaid),
        repayments: Value(LoanRepayment.listToJson(updated)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> addDisbursement(
    int loanId,
    double amount, {
    DateTime? dueDate,
    String? note,
  }) async {
    final loan = await getById(loanId);
    if (loan == null) return;
    final disbursement = LoanDisbursement(
      amount: amount,
      date: DateTime.now(),
      dueDate: dueDate,
      note: note,
    );
    final updated = [...loan.disbursements, disbursement];
    final newPrincipal = loan.principalAmount + amount;
    await (_d.update(_d.loans)..where((l) => l.id.equals(loanId))).write(
      LoansCompanion(
        principalAmount: Value(newPrincipal),
        disbursements: Value(LoanDisbursement.listToJson(updated)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> closeLoan(int id) async {
    await (_d.update(_d.loans)..where((l) => l.id.equals(id))).write(
      LoansCompanion(
        isClosed: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reopenLoan(int id) async {
    await (_d.update(_d.loans)..where((l) => l.id.equals(id))).write(
      LoansCompanion(
        isClosed: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Returns distinct person names across all loan records.
  Future<List<String>> getDistinctPersonNames() async {
    final all = await getAll();
    return all.map((l) => l.personName).toSet().toList()..sort();
  }

  /// Returns the first active (non-closed) loan ledger for a person+type combo.
  Future<LoanModel?> findActiveLedger(String personName, int type) async {
    final row = await (_d.select(_d.loans)
          ..where((l) =>
              l.personName.equals(personName) &
              l.type.equals(type) &
              l.isClosed.equals(false)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Stream<void> watchAll() =>
      _d.select(_d.loans).watch().map((_) {});
}
