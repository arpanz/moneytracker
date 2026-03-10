import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../domain/models/loan_model.dart';

/// Aggregate stats displayed in the loans dashboard.
class LoanSummary {
  final int totalLoans;
  final int activeLoans;
  final int closedLoans;
  final int overdueLoans;
  final double receivable;
  final double payable;
  final double netPosition;

  const LoanSummary({
    required this.totalLoans,
    required this.activeLoans,
    required this.closedLoans,
    required this.overdueLoans,
    required this.receivable,
    required this.payable,
    required this.netPosition,
  });

  static const empty = LoanSummary(
    totalLoans: 0,
    activeLoans: 0,
    closedLoans: 0,
    overdueLoans: 0,
    receivable: 0,
    payable: 0,
    netPosition: 0,
  );
}

final loanListProvider = StreamProvider<List<LoanModel>>((ref) async* {
  final repo = ref.watch(loanRepositoryProvider);
  yield await repo.getAll();
  await for (final _ in repo.watchAll()) {
    yield await repo.getAll();
  }
});

final activeLoansProvider = Provider<List<LoanModel>>((ref) {
  final loans = ref.watch(loanListProvider).valueOrNull ?? [];
  return loans.where((loan) => !loan.isClosed).toList();
});

final lendingLoansProvider = Provider<List<LoanModel>>((ref) {
  return ref
      .watch(activeLoansProvider)
      .where((loan) => loan.type == 0)
      .toList();
});

final borrowingLoansProvider = Provider<List<LoanModel>>((ref) {
  return ref
      .watch(activeLoansProvider)
      .where((loan) => loan.type == 1)
      .toList();
});

final closedLoansProvider = Provider<List<LoanModel>>((ref) {
  final loans = ref.watch(loanListProvider).valueOrNull ?? [];
  return loans.where((loan) => loan.isClosed).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
});

final overdueLoansProvider = Provider<List<LoanModel>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ref
      .watch(activeLoansProvider)
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
});

final loanSummaryProvider = Provider<LoanSummary>((ref) {
  final allLoans = ref.watch(loanListProvider).valueOrNull ?? [];
  if (allLoans.isEmpty) return LoanSummary.empty;

  final active = allLoans.where((loan) => !loan.isClosed).toList();
  final closed = allLoans.where((loan) => loan.isClosed).toList();
  final overdue = ref.watch(overdueLoansProvider);

  double receivable = 0;
  double payable = 0;

  for (final loan in active) {
    if (loan.type == 0) {
      receivable += loan.outstandingAmount;
    } else {
      payable += loan.outstandingAmount;
    }
  }

  return LoanSummary(
    totalLoans: allLoans.length,
    activeLoans: active.length,
    closedLoans: closed.length,
    overdueLoans: overdue.length,
    receivable: receivable,
    payable: payable,
    netPosition: receivable - payable,
  );
});

final loanByIdProvider = FutureProvider.family<LoanModel?, int>((ref, id) {
  final repo = ref.watch(loanRepositoryProvider);
  return repo.getById(id);
});
