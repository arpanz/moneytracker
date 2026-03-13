import 'dart:convert';

/// Embedded object representing a participant in a split expense.
class SplitParticipant {
  String name;
  String? contact;
  double amount;
  double? percentage;
  bool isSettled;

  SplitParticipant({
    this.name = '',
    this.contact,
    this.amount = 0.0,
    this.percentage,
    this.isSettled = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'contact': contact,
        'amount': amount,
        'percentage': percentage,
        'isSettled': isSettled,
      };

  factory SplitParticipant.fromJson(Map<String, dynamic> j) => SplitParticipant(
        name: j['name'] as String,
        contact: j['contact'] as String?,
        amount: (j['amount'] as num).toDouble(),
        percentage: (j['percentage'] as num?)?.toDouble(),
        isSettled: j['isSettled'] as bool? ?? false,
      );

  static List<SplitParticipant> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SplitParticipant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<SplitParticipant> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}

/// Represents a split expense shared among multiple people.
class SplitModel {
  int id;

  /// Link to the originating transaction (stored as string for flexibility).
  String? transactionId;

  String description;
  double totalAmount;

  /// 0 = equal, 1 = exact, 2 = percentage
  int splitMethod;

  List<SplitParticipant> participants;
  bool isFullySettled;
  DateTime createdAt;

  int get unsettledCount => participants.where((p) => !p.isSettled).length;

  SplitModel({
    this.id = 0,
    this.transactionId,
    this.description = '',
    this.totalAmount = 0.0,
    this.splitMethod = 0,
    List<SplitParticipant>? participants,
    this.isFullySettled = false,
    DateTime? createdAt,
  })  : participants = participants ?? [],
        createdAt = createdAt ?? DateTime.now();
}
