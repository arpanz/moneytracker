import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Table definitions
// ─────────────────────────────────────────────────────────────────────────────

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get accountType => integer().withDefault(const Constant(0))();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  RealColumn get creditLimit => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get icon => text().withDefault(const Constant('wallet'))();
  IntColumn get color =>
      integer().withDefault(const Constant(0xFF4CAF50))();
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  TextColumn get subcategory => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime()();
  IntColumn get type => integer().withDefault(const Constant(1))();
  TextColumn get receiptImagePath => text().nullable()();
  BoolColumn get isRecurring =>
      boolean().withDefault(const Constant(false))();
  TextColumn get recurringRule => text().nullable()();
  TextColumn get splitId => text().nullable()();
  /// JSON-encoded List<String>
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get accountId => text()();
  TextColumn get toAccountId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get color => integer().withDefault(const Constant(0xFF9E9E9E))();
  IntColumn get type => integer().withDefault(const Constant(0))();
  BoolColumn get isCustom =>
      boolean().withDefault(const Constant(false))();
  TextColumn get parentId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  RealColumn get limitAmount => real()();
  IntColumn get period => integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
}

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount =>
      real().withDefault(const Constant(0.0))();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get icon =>
      text().withDefault(const Constant('piggy-bank'))();
  IntColumn get color =>
      integer().withDefault(const Constant(0xFF7C3AED))();
  TextColumn get linkedAccountId => text().nullable()();
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  /// JSON-encoded List<GoalContribution>
  TextColumn get contributions =>
      text().withDefault(const Constant('[]'))();
}

class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  IntColumn get frequency => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextBillDate => dateTime()();
  TextColumn get category =>
      text().withDefault(const Constant('Subscriptions'))();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isAutoDetected =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class Splits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transactionId => text().nullable()();
  TextColumn get description => text()();
  RealColumn get totalAmount => real()();
  IntColumn get splitMethod => integer().withDefault(const Constant(0))();
  /// JSON-encoded List<SplitParticipant>
  TextColumn get participants =>
      text().withDefault(const Constant('[]'))();
  BoolColumn get isFullySettled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class Loans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get type => integer().withDefault(const Constant(0))();
  TextColumn get personName => text()();
  TextColumn get title => text().nullable()();
  RealColumn get principalAmount => real()();
  RealColumn get paidAmount =>
      real().withDefault(const Constant(0.0))();
  RealColumn get interestRate => real().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isClosed =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  /// JSON-encoded List<LoanDisbursement>
  TextColumn get disbursements =>
      text().withDefault(const Constant('[]'))();
  /// JSON-encoded List<LoanRepayment>
  TextColumn get repayments =>
      text().withDefault(const Constant('[]'))();
}

// ─────────────────────────────────────────────────────────────────────────────
// Database
// ─────────────────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Accounts,
  Transactions,
  Categories,
  Budgets,
  Goals,
  Subscriptions,
  Splits,
  Loans,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'cheddar_db');
  }
}
