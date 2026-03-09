import 'package:isar/isar.dart';

part 'split_model.g.dart';

/// Embedded object representing a participant in a split expense.
@embedded
class SplitParticipant {
  late String name;
  String? contact;
  late double amount;
  double? percentage;
  late bool isSettled;

  SplitParticipant() : amount = 0.0, isSettled = false;
}

/// Represents a split expense shared among multiple people.
@collection
class SplitModel {
  Id id = Isar.autoIncrement;

  /// Link to the originating transaction (stored as string for flexibility).
  String? transactionId;

  late String description;

  late double totalAmount;

  /// 0 = equal, 1 = exact, 2 = percentage
  late int splitMethod;

  late List<SplitParticipant> participants;

  @Index()
  late bool isFullySettled;

  late DateTime createdAt;

  /// Computed count of unsettled participants.
  @ignore
  int get unsettledCount =>
      participants.where((p) => !p.isSettled).length;

  SplitModel()
      : splitMethod = 0,
        participants = [],
        isFullySettled = false,
        createdAt = DateTime.now();
}
