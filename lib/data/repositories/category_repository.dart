import 'package:drift/drift.dart';

import '../../domain/models/category_model.dart';
import '../local/database_service.dart';

/// Repository for managing transaction categories.
class CategoryRepository {
  final DatabaseService _db;

  CategoryRepository(this._db);

  AppDatabase get _d => _db.db;

  // ── Mapping ──────────────────────────────────────────────────────────────

  CategoryModel _fromRow(Category row) => CategoryModel(
        id: row.id,
        name: row.name,
        icon: row.icon,
        color: row.color,
        type: row.type,
        isCustom: row.isCustom,
        parentId: row.parentId,
        sortOrder: row.sortOrder,
        createdAt: row.createdAt,
      );

  CategoriesCompanion _toCompanion(CategoryModel c) =>
      CategoriesCompanion.insert(
        name: c.name,
        icon: c.icon,
        color: Value(c.color),
        type: Value(c.type),
        isCustom: Value(c.isCustom),
        parentId: Value(c.parentId),
        sortOrder: Value(c.sortOrder),
        createdAt: c.createdAt,
      );

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<int> add(CategoryModel category) =>
      _d.into(_d.categories).insert(_toCompanion(category));

  Future<void> update(CategoryModel category) async {
    await (_d.update(_d.categories)
          ..where((c) => c.id.equals(category.id)))
        .write(CategoriesCompanion(
      name: Value(category.name),
      icon: Value(category.icon),
      color: Value(category.color),
      type: Value(category.type),
      isCustom: Value(category.isCustom),
      parentId: Value(category.parentId),
      sortOrder: Value(category.sortOrder),
    ));
  }

  Future<void> delete(int id) async {
    await (_d.delete(_d.categories)..where((c) => c.id.equals(id))).go();
  }

  Future<CategoryModel?> getById(int id) async {
    final row = await (_d.select(_d.categories)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<CategoryModel>> getAll() async {
    final rows = await (_d.select(_d.categories)
          ..orderBy([
            (c) => OrderingTerm.asc(c.sortOrder),
            (c) => OrderingTerm.asc(c.name),
          ]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<CategoryModel>> getByType(int type) async {
    final rows = await (_d.select(_d.categories)
          ..where((c) => c.type.equals(type) | c.type.equals(2))
          ..orderBy([
            (c) => OrderingTerm.asc(c.sortOrder),
            (c) => OrderingTerm.asc(c.name),
          ]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<CategoryModel>> getCustom() async {
    final rows = await (_d.select(_d.categories)
          ..where((c) => c.isCustom.equals(true)))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<bool> exists(String name, int type) async {
    final row = await (_d.select(_d.categories)
          ..where((c) => c.name.equals(name) & c.type.equals(type)))
        .getSingleOrNull();
    return row != null;
  }

  /// Seeds the default categories if the table is empty.
  Future<void> seedDefaultsIfEmpty() async {
    final count = await _d.select(_d.categories).get();
    if (count.isNotEmpty) return;

    final defaults = _defaultCategories();
    for (final cat in defaults) {
      await add(cat);
    }
  }

  List<CategoryModel> _defaultCategories() {
    final now = DateTime.now();
    var order = 0;

    CategoryModel make(
      String name,
      String icon,
      int color,
      int type, {
      bool isCustom = false,
    }) =>
        CategoryModel(
          name: name,
          icon: icon,
          color: color,
          type: type,
          isCustom: isCustom,
          sortOrder: order++,
          createdAt: now,
        );

    return [
      // Expense categories
      make('Food', 'assets/svg/categories/food.svg', 0xFFFF6B6B, 0),
      make('Transport', 'assets/svg/categories/transport.svg', 0xFF4ECDC4, 0),
      make('Shopping', 'assets/svg/categories/shopping.svg', 0xFFFFE66D, 0),
      make('Bills', 'assets/svg/categories/bills.svg', 0xFF95E1D3, 0),
      make('Entertainment', 'assets/svg/categories/entertainment.svg', 0xFFF38181, 0),
      make('Health', 'assets/svg/categories/health.svg', 0xFF6BCB77, 0),
      make('Education', 'assets/svg/categories/education.svg', 0xFF4D96FF, 0),
      make('Travel', 'assets/svg/categories/travel.svg', 0xFFFF9F1C, 0),
      make('Gifts', 'assets/svg/categories/gifts.svg', 0xFFE76F51, 0),
      make('Rent', 'assets/svg/categories/rent.svg', 0xFF9B5DE5, 0),
      make('Groceries', 'assets/svg/categories/groceries.svg', 0xFF56CFE1, 0),
      make('Pets', 'assets/svg/categories/pets.svg', 0xFFFF99C8, 0),
      make('Subscriptions', 'assets/svg/categories/subscriptions.svg', 0xFF7209B7, 0),
      make('Other', 'assets/svg/categories/other.svg', 0xFF9E9E9E, 0),
      // Income categories
      make('Salary', 'assets/svg/categories/salary.svg', 0xFF2EC4B6, 1),
      make('Freelance', 'assets/svg/categories/freelance.svg', 0xFFFF9F1C, 1),
      make('Investments', 'assets/svg/categories/investments.svg', 0xFF6BCB77, 1),
    ];
  }

  Stream<void> watchAll() =>
      _d.select(_d.categories).watch().map((_) {});
}
