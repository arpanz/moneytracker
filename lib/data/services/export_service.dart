import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../local/database_service.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/goal_repository.dart';
import '../repositories/subscription_repository.dart';
import '../repositories/split_repository.dart';
import '../repositories/category_repository.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/budget_model.dart';
import '../../domain/models/goal_model.dart';
import '../../domain/models/subscription_model.dart';
import '../../domain/models/split_model.dart';

/// Service for exporting app data as CSV, PDF, or JSON backup.
class ExportService {
  final TransactionRepository _txnRepo;
  final AccountRepository _accountRepo;
  final BudgetRepository _budgetRepo;
  final GoalRepository _goalRepo;
  final SubscriptionRepository _subRepo;
  final SplitRepository _splitRepo;

  ExportService({
    required TransactionRepository transactionRepo,
    required AccountRepository accountRepo,
    required BudgetRepository budgetRepo,
    required GoalRepository goalRepo,
    required SubscriptionRepository subscriptionRepo,
    required SplitRepository splitRepo,
  })  : _txnRepo = transactionRepo,
        _accountRepo = accountRepo,
        _budgetRepo = budgetRepo,
        _goalRepo = goalRepo,
        _subRepo = subscriptionRepo,
        _splitRepo = splitRepo;

  // ── CSV Export ────────────────────────────────────────────────────────────

  /// Exports all transactions to CSV and returns the file path.
  Future<String> exportTransactionsCsv({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final transactions = await _txnRepo.getAll();
    final filtered = transactions.where((t) {
      if (startDate != null && t.date.isBefore(startDate)) return false;
      if (endDate != null && t.date.isAfter(endDate)) return false;
      return true;
    }).toList();

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    final rows = <List<dynamic>>[
      // Header row
      [
        'Date',
        'Type',
        'Category',
        'Amount',
        'Note',
        'Account ID',
        'From Notification',
      ],
      // Data rows
      ...filtered.map((t) => [
            dateFormat.format(t.date),
            t.type == 0 ? 'Income' : 'Expense',
            t.category,
            t.amount.toStringAsFixed(2),
            t.note ?? '',
            t.accountId?.toString() ?? '',
            t.isFromNotification ? 'Yes' : 'No',
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/cheddar_transactions_$timestamp.csv');
    await file.writeAsString(csv);

    return file.path;
  }

  /// Share the CSV export via the system share sheet.
  Future<void> shareTransactionsCsv({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final path = await exportTransactionsCsv(
      startDate: startDate,
      endDate: endDate,
    );
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Cheddar Transactions Export',
    );
  }

  // ── JSON Backup ───────────────────────────────────────────────────────────

  /// Creates a complete JSON backup of all app data.
  /// Returns the file path of the backup.
  Future<String> createBackup() async {
    final transactions = await _txnRepo.getAll();
    final accounts = await _accountRepo.getAll();
    final budgets = await _budgetRepo.getAll();
    final goals = await _goalRepo.getAll();
    final subscriptions = await _subRepo.getAll();
    final splits = await _splitRepo.getAll();

    final backup = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'Cheddar',
      'data': {
        'transactions': transactions.map(_txnToJson).toList(),
        'accounts': accounts.map(_accountToJson).toList(),
        'budgets': budgets.map(_budgetToJson).toList(),
        'goals': goals.map(_goalToJson).toList(),
        'subscriptions': subscriptions.map(_subscriptionToJson).toList(),
        'splits': splits.map(_splitToJson).toList(),
      },
      'counts': {
        'transactions': transactions.length,
        'accounts': accounts.length,
        'budgets': budgets.length,
        'goals': goals.length,
        'subscriptions': subscriptions.length,
        'splits': splits.length,
      },
    };

    final json = const JsonEncoder.withIndent('  ').convert(backup);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/cheddar_backup_$timestamp.json');
    await file.writeAsString(json);

    return file.path;
  }

  /// Share the JSON backup via the system share sheet.
  Future<void> shareBackup() async {
    final path = await createBackup();
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Cheddar Backup',
    );
  }

  /// Restores app data from a JSON backup file.
  /// Returns a summary of what was restored.
  Future<Map<String, int>> restoreFromBackup(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Backup file not found');
    }

    final content = await file.readAsString();
    final backup = jsonDecode(content) as Map<String, dynamic>;

    // Validate backup format
    if (backup['appName'] != 'Cheddar' || backup['version'] == null) {
      throw Exception('Invalid backup file format');
    }

    final data = backup['data'] as Map<String, dynamic>;
    final counts = <String, int>{};

    // Restore transactions
    if (data.containsKey('transactions')) {
      final items = (data['transactions'] as List)
          .map((j) => _txnFromJson(j as Map<String, dynamic>))
          .toList();
      for (final item in items) {
        await _txnRepo.add(item);
      }
      counts['transactions'] = items.length;
    }

    // Restore accounts
    if (data.containsKey('accounts')) {
      final items = (data['accounts'] as List)
          .map((j) => _accountFromJson(j as Map<String, dynamic>))
          .toList();
      for (final item in items) {
        await _accountRepo.add(item);
      }
      counts['accounts'] = items.length;
    }

    // Restore budgets
    if (data.containsKey('budgets')) {
      final items = (data['budgets'] as List)
          .map((j) => _budgetFromJson(j as Map<String, dynamic>))
          .toList();
      for (final item in items) {
        await _budgetRepo.add(item);
      }
      counts['budgets'] = items.length;
    }

    // Restore goals
    if (data.containsKey('goals')) {
      final items = (data['goals'] as List)
          .map((j) => _goalFromJson(j as Map<String, dynamic>))
          .toList();
      for (final item in items) {
        await _goalRepo.add(item);
      }
      counts['goals'] = items.length;
    }

    // Restore subscriptions
    if (data.containsKey('subscriptions')) {
      final items = (data['subscriptions'] as List)
          .map((j) => _subscriptionFromJson(j as Map<String, dynamic>))
          .toList();
      for (final item in items) {
        await _subRepo.add(item);
      }
      counts['subscriptions'] = items.length;
    }

    // Restore splits
    if (data.containsKey('splits')) {
      final items = (data['splits'] as List)
          .map((j) => _splitFromJson(j as Map<String, dynamic>))
          .toList();
      for (final item in items) {
        await _splitRepo.add(item);
      }
      counts['splits'] = items.length;
    }

    return counts;
  }

  // ── JSON Serialization Helpers ────────────────────────────────────────────

  Map<String, dynamic> _txnToJson(TransactionModel t) => {
        'amount': t.amount,
        'type': t.type,
        'category': t.category,
        'note': t.note,
        'date': t.date.toIso8601String(),
        'accountId': t.accountId,
        'receiptPath': t.receiptPath,
        'isFromNotification': t.isFromNotification,
        'createdAt': t.createdAt.toIso8601String(),
      };

  TransactionModel _txnFromJson(Map<String, dynamic> j) => TransactionModel()
    ..amount = (j['amount'] as num).toDouble()
    ..type = j['type'] as int
    ..category = j['category'] as String
    ..note = j['note'] as String?
    ..date = DateTime.parse(j['date'] as String)
    ..accountId = j['accountId'] as int?
    ..receiptPath = j['receiptPath'] as String?
    ..isFromNotification = j['isFromNotification'] as bool? ?? false
    ..createdAt = DateTime.parse(j['createdAt'] as String);

  Map<String, dynamic> _accountToJson(AccountModel a) => {
        'name': a.name,
        'type': a.type,
        'balance': a.balance,
        'createdAt': a.createdAt.toIso8601String(),
      };

  AccountModel _accountFromJson(Map<String, dynamic> j) => AccountModel()
    ..name = j['name'] as String
    ..type = j['type'] as int
    ..balance = (j['balance'] as num).toDouble()
    ..createdAt = DateTime.parse(j['createdAt'] as String);

  Map<String, dynamic> _budgetToJson(BudgetModel b) => {
        'category': b.category,
        'limitAmount': b.limitAmount,
        'period': b.period,
        'createdAt': b.createdAt.toIso8601String(),
      };

  BudgetModel _budgetFromJson(Map<String, dynamic> j) => BudgetModel()
    ..category = j['category'] as String
    ..limitAmount = (j['limitAmount'] as num).toDouble()
    ..period = j['period'] as int
    ..createdAt = DateTime.parse(j['createdAt'] as String);

  Map<String, dynamic> _goalToJson(GoalModel g) => {
        'name': g.name,
        'targetAmount': g.targetAmount,
        'currentAmount': g.currentAmount,
        'deadline': g.deadline.toIso8601String(),
        'iconName': g.iconName,
        'colorValue': g.colorValue,
        'linkedAccountId': g.linkedAccountId,
        'createdAt': g.createdAt.toIso8601String(),
      };

  GoalModel _goalFromJson(Map<String, dynamic> j) => GoalModel()
    ..name = j['name'] as String
    ..targetAmount = (j['targetAmount'] as num).toDouble()
    ..currentAmount = (j['currentAmount'] as num).toDouble()
    ..deadline = DateTime.parse(j['deadline'] as String)
    ..iconName = j['iconName'] as String?
    ..colorValue = j['colorValue'] as int?
    ..linkedAccountId = j['linkedAccountId'] as int?
    ..createdAt = DateTime.parse(j['createdAt'] as String);

  Map<String, dynamic> _subscriptionToJson(SubscriptionModel s) => {
        'name': s.name,
        'amount': s.amount,
        'frequency': s.frequency,
        'nextBillDate': s.nextBillDate.toIso8601String(),
        'category': s.category,
        'logoUrl': s.logoUrl,
        'notes': s.notes,
        'isActive': s.isActive,
        'isAutoDetected': s.isAutoDetected,
        'createdAt': s.createdAt.toIso8601String(),
      };

  SubscriptionModel _subscriptionFromJson(Map<String, dynamic> j) =>
      SubscriptionModel()
        ..name = j['name'] as String
        ..amount = (j['amount'] as num).toDouble()
        ..frequency = j['frequency'] as int
        ..nextBillDate = DateTime.parse(j['nextBillDate'] as String)
        ..category = j['category'] as String? ?? 'Subscriptions'
        ..logoUrl = j['logoUrl'] as String?
        ..notes = j['notes'] as String?
        ..isActive = j['isActive'] as bool? ?? true
        ..isAutoDetected = j['isAutoDetected'] as bool? ?? false
        ..createdAt = DateTime.parse(j['createdAt'] as String);

  Map<String, dynamic> _splitToJson(SplitModel s) => {
        'description': s.description,
        'totalAmount': s.totalAmount,
        'splitMethod': s.splitMethod,
        'isFullySettled': s.isFullySettled,
        'createdAt': s.createdAt.toIso8601String(),
        'participants': s.participants
            .map((p) => {
                  'name': p.name,
                  'contact': p.contact,
                  'amount': p.amount,
                  'percentage': p.percentage,
                  'isSettled': p.isSettled,
                })
            .toList(),
      };

  SplitModel _splitFromJson(Map<String, dynamic> j) {
    final split = SplitModel()
      ..description = j['description'] as String
      ..totalAmount = (j['totalAmount'] as num).toDouble()
      ..splitMethod = j['splitMethod'] as int
      ..isFullySettled = j['isFullySettled'] as bool? ?? false
      ..createdAt = DateTime.parse(j['createdAt'] as String);

    split.participants = ((j['participants'] as List?) ?? [])
        .map((pj) {
          final p = SplitParticipant()
            ..name = pj['name'] as String
            ..contact = pj['contact'] as String?
            ..amount = (pj['amount'] as num).toDouble()
            ..percentage = (pj['percentage'] as num?)?.toDouble()
            ..isSettled = pj['isSettled'] as bool? ?? false;
          return p;
        })
        .toList();

    return split;
  }
}
