/// Represents a recurring subscription or bill.
class SubscriptionModel {
  int id;

  String name;

  double amount;

  /// 0 = weekly, 1 = monthly, 2 = quarterly, 3 = yearly
  int frequency;

  DateTime nextBillDate;

  String category;

  /// URL or asset path for the subscription service logo.
  String? logoUrl;

  String? notes;

  bool isActive;

  /// Whether this subscription was auto-detected from transaction patterns.
  bool isAutoDetected;

  DateTime createdAt;

  SubscriptionModel({
    this.id = 0,
    this.name = '',
    this.amount = 0.0,
    this.frequency = 1,
    DateTime? nextBillDate,
    this.category = 'Subscriptions',
    this.logoUrl,
    this.notes,
    this.isActive = true,
    this.isAutoDetected = false,
    DateTime? createdAt,
  })  : nextBillDate = nextBillDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();
}
