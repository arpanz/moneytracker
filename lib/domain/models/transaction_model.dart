/// Represents a financial transaction (income, expense, or transfer).
class TransactionModel {
  int id;
  double amount;
  String category;
  String? subcategory;
  String? note;
  DateTime date;

  /// 0 = income, 1 = expense, 2 = transfer
  int type;

  bool isRecurring;

  /// JSON string: {"frequency":"monthly","interval":1,"endDate":null}
  String? recurringRule;

  /// Link to a SplitModel id (stored as string for flexibility)
  String? splitId;

  List<String> tags;

  String accountId;

  /// Destination account for transfer-type transactions
  String? toAccountId;

  DateTime createdAt;

  TransactionModel({
    this.id = 0,
    this.amount = 0.0,
    this.category = '',
    this.subcategory,
    this.note,
    DateTime? date,
    this.type = 1,
    this.isRecurring = false,
    this.recurringRule,
    this.splitId,
    List<String>? tags,
    this.accountId = '',
    this.toAccountId,
    DateTime? createdAt,
  }) : date = date ?? DateTime.now(),
       tags = tags ?? [],
       createdAt = createdAt ?? DateTime.now();
}
