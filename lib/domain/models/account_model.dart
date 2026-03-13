/// Represents a financial account (checking, savings, credit, cash, investment).
class AccountModel {
  int id;

  /// Unique account name.
  String name;

  /// 0 = checking, 1 = savings, 2 = credit, 3 = cash, 4 = investment
  int accountType;

  double balance;

  /// Only applicable for credit card accounts.
  double? creditLimit;

  String currency;

  /// FontAwesome icon name (e.g. 'wallet', 'credit-card').
  String icon;

  /// Color value stored as int (e.g. 0xFF4CAF50).
  int color;

  bool isArchived;

  DateTime createdAt;

  AccountModel({
    this.id = 0,
    this.name = '',
    this.accountType = 0,
    this.balance = 0.0,
    this.creditLimit,
    this.currency = 'INR',
    this.icon = 'wallet',
    this.color = 0xFF4CAF50,
    this.isArchived = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
