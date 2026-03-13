import 'dart:convert';

/// A single contribution toward a goal.
class GoalContribution {
  double amount;
  DateTime date;
  String? note;

  GoalContribution({
    this.amount = 0.0,
    DateTime? date,
    this.note,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory GoalContribution.fromJson(Map<String, dynamic> j) =>
      GoalContribution(
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String?,
      );

  static List<GoalContribution> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => GoalContribution.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<GoalContribution> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}

/// Represents a savings goal with tracked contributions.
class GoalModel {
  int id;
  String name;
  double targetAmount;
  double currentAmount;
  DateTime? deadline;

  /// FontAwesome icon name (e.g. 'piggy-bank', 'plane').
  String icon;

  /// Color value stored as int.
  int color;

  /// Optional link to an account for automatic tracking.
  String? linkedAccountId;

  bool isCompleted;
  DateTime createdAt;
  List<GoalContribution> contributions;

  /// Computed progress as a fraction (0.0 to 1.0+).
  double get progress =>
      targetAmount > 0 ? currentAmount / targetAmount : 0.0;

  GoalModel({
    this.id = 0,
    this.name = '',
    this.targetAmount = 0.0,
    this.currentAmount = 0.0,
    this.deadline,
    this.icon = 'piggy-bank',
    this.color = 0xFF7C3AED,
    this.linkedAccountId,
    this.isCompleted = false,
    DateTime? createdAt,
    List<GoalContribution>? contributions,
  })  : createdAt = createdAt ?? DateTime.now(),
        contributions = contributions ?? [];
}
