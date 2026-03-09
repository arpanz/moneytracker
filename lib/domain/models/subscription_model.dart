import 'package:isar/isar.dart';

part 'subscription_model.g.dart';

/// Represents a recurring subscription or bill.
@collection
class SubscriptionModel {
  Id id = Isar.autoIncrement;

  late String name;

  late double amount;

  /// 0 = weekly, 1 = monthly, 2 = quarterly, 3 = yearly
  late int frequency;

  @Index()
  late DateTime nextBillDate;

  late String category;

  /// URL or asset path for the subscription service logo.
  String? logoUrl;

  String? notes;

  @Index()
  late bool isActive;

  /// Whether this subscription was auto-detected from transaction patterns.
  late bool isAutoDetected;

  late DateTime createdAt;

  SubscriptionModel()
      : frequency = 1,
        category = 'Subscriptions',
        isActive = true,
        isAutoDetected = false,
        createdAt = DateTime.now();
}
