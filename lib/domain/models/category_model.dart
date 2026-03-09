import 'package:isar/isar.dart';

part 'category_model.g.dart';

/// Represents a transaction category (expense, income, or both).
@collection
class CategoryModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name;

  /// SVG asset path (e.g. 'assets/svg/categories/food.svg').
  late String icon;

  /// Color value stored as int.
  late int color;

  /// 0 = expense, 1 = income, 2 = both
  @Index()
  late int type;

  /// Whether this is a user-created category vs. a default one.
  late bool isCustom;

  /// Parent category id as string for sub-categories. Null for top-level.
  String? parentId;

  @Index()
  late int sortOrder;

  late DateTime createdAt;

  CategoryModel()
      : type = 0,
        isCustom = false,
        sortOrder = 0,
        createdAt = DateTime.now();
}
