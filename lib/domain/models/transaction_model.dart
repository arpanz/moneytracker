import 'package:isar/isar.dart';

part 'transaction_model.g.dart';

/// Represents a financial transaction (income, expense, or transfer).
@collection
class TransactionModel {
  Id id = Isar.autoIncrement;

  late double amount;

  @Index()
  late String category;

  String? subcategory;

  String? note;

  @Index()
  late DateTime date;

  /// 0 = income, 1 = expense, 2 = transfer
  @Index()
  late int type;

  String? receiptImagePath;

  late bool isRecurring;

  /// JSON string: {"frequency":"monthly","interval":1,"endDate":null}
  String? recurringRule;

  /// Link to a SplitModel id (stored as string for flexibility)
  String? splitId;

  late List<String> tags;

  @Index()
  late String accountId;

  /// Destination account for transfer-type transactions
  String? toAccountId;

  late DateTime createdAt;

  /// Composite index on [date, type] for efficient date+type queries.
  @Index(composite: [CompositeIndex('type')])
  DateTime get compositeDateTime => date;

  TransactionModel()
      : isRecurring = false,
        tags = [],
        createdAt = DateTime.now();
}
