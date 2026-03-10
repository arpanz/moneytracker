import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/transaction_model.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/budget_model.dart';
import '../../domain/models/goal_model.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/subscription_model.dart';
import '../../domain/models/split_model.dart';
import '../../domain/models/loan_model.dart';

class DatabaseService {
  late Isar _isar;

  Isar get isar => _isar;

  Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        TransactionModelSchema,
        AccountModelSchema,
        BudgetModelSchema,
        GoalModelSchema,
        CategoryModelSchema,
        SubscriptionModelSchema,
        SplitModelSchema,
        LoanModelSchema,
      ],
      directory: dir.path,
      name: 'cheddar_db',
    );
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.clear();
    });
  }

  Future<void> close() async {
    await _isar.close();
  }
}
