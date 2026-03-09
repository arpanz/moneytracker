import 'package:isar/isar.dart';

part 'account_model.g.dart';

/// Represents a financial account (checking, savings, credit, cash, investment).
@collection
class AccountModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name;

  /// 0 = checking, 1 = savings, 2 = credit, 3 = cash, 4 = investment
  @Index()
  late int accountType;

  late double balance;

  /// Only applicable for credit card accounts.
  double? creditLimit;

  late String currency;

  /// FontAwesome icon name (e.g. 'wallet', 'credit-card').
  late String icon;

  /// Color value stored as int (e.g. 0xFF4CAF50).
  late int color;

  late bool isArchived;

  late DateTime createdAt;

  AccountModel()
      : balance = 0.0,
        currency = 'INR',
        icon = 'wallet',
        color = 0xFF4CAF50,
        isArchived = false,
        createdAt = DateTime.now();
}
