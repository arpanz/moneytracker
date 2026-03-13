/// Represents a transaction category (expense, income, or both).
class CategoryModel {
  int id;

  String name;

  /// SVG asset path (e.g. 'assets/svg/categories/food.svg').
  String icon;

  /// Color value stored as int.
  int color;

  /// 0 = expense, 1 = income, 2 = both
  int type;

  /// Whether this is a user-created category vs. a default one.
  bool isCustom;

  /// Parent category id as string for sub-categories. Null for top-level.
  String? parentId;

  int sortOrder;

  DateTime createdAt;

  CategoryModel({
    this.id = 0,
    this.name = '',
    this.icon = '',
    this.color = 0xFF9E9E9E,
    this.type = 0,
    this.isCustom = false,
    this.parentId,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
