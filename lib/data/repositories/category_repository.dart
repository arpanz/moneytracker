import 'package:isar/isar.dart';

import '../../domain/models/category_model.dart';
import '../../config/constants/asset_paths.dart';
import '../local/database_service.dart';

/// Repository for managing transaction categories.
///
/// Provides CRUD operations, type-based filtering, custom category queries,
/// default category seeding, and a real-time watch stream.
class CategoryRepository {
  final DatabaseService _db;

  CategoryRepository(this._db);

  Isar get _isar => _db.isar;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserts a new category and returns its auto-generated id.
  Future<int> add(CategoryModel category) async {
    return _isar.writeTxn(() async {
      return _isar.categoryModels.put(category);
    });
  }

  /// Updates an existing category in-place.
  Future<void> update(CategoryModel category) async {
    await _isar.writeTxn(() async {
      await _isar.categoryModels.put(category);
    });
  }

  /// Deletes a category by its id.
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.categoryModels.delete(id);
    });
  }

  /// Retrieves a single category by id, or null if not found.
  Future<CategoryModel?> getById(int id) async {
    return _isar.categoryModels.get(id);
  }

  /// Returns all categories ordered by sort order.
  Future<List<CategoryModel>> getAll() async {
    return _isar.categoryModels
        .where()
        .sortBySortOrder()
        .findAll();
  }

  // ── FILTERED QUERIES ─────────────────────────────────────────────────────

  /// Returns categories of a given type (0=expense, 1=income, 2=both).
  ///
  /// Also includes categories marked as type 2 (both) in the results.
  Future<List<CategoryModel>> getByType(int type) async {
    return _isar.categoryModels
        .filter()
        .typeEqualTo(type)
        .or()
        .typeEqualTo(2) // include "both" categories
        .sortBySortOrder()
        .findAll();
  }

  /// Returns all user-created (custom) categories.
  Future<List<CategoryModel>> getCustom() async {
    return _isar.categoryModels
        .filter()
        .isCustomEqualTo(true)
        .sortBySortOrder()
        .findAll();
  }

  // ── SEED DEFAULTS ────────────────────────────────────────────────────────

  /// Seeds the 16 default categories if the collection is empty.
  ///
  /// Called during app initialization to ensure categories are available
  /// on first launch. Does nothing if categories already exist.
  Future<void> seedDefaults() async {
    final count = await _isar.categoryModels.count();
    if (count > 0) return;

    final defaults = <CategoryModel>[
      _makeCategory('Food', AssetPaths.categoryFood, 0xFFFF6B6B, 0, 0),
      _makeCategory('Transport', AssetPaths.categoryTransport, 0xFF4ECDC4, 0, 1),
      _makeCategory('Shopping', AssetPaths.categoryShopping, 0xFFFF8A65, 0, 2),
      _makeCategory('Bills', AssetPaths.categoryBills, 0xFFFFD93D, 0, 3),
      _makeCategory('Entertainment', AssetPaths.categoryEntertainment, 0xFFA78BFA, 0, 4),
      _makeCategory('Health', AssetPaths.categoryHealth, 0xFFEF4444, 0, 5),
      _makeCategory('Education', AssetPaths.categoryEducation, 0xFF60A5FA, 0, 6),
      _makeCategory('Travel', AssetPaths.categoryTravel, 0xFF34D399, 0, 7),
      _makeCategory('Gifts', AssetPaths.categoryGifts, 0xFFF472B6, 0, 8),
      _makeCategory('Rent', AssetPaths.categoryRent, 0xFF8B5CF6, 0, 9),
      _makeCategory('Groceries', AssetPaths.categoryGroceries, 0xFF10B981, 0, 10),
      _makeCategory('Pets', AssetPaths.categoryPets, 0xFFFBBF24, 0, 11),
      _makeCategory('Subscriptions', AssetPaths.categorySubscriptions, 0xFF6366F1, 0, 12),
      _makeCategory('Salary', AssetPaths.categorySalary, 0xFF22C55E, 1, 13),
      _makeCategory('Freelance', AssetPaths.categoryFreelance, 0xFF06B6D4, 1, 14),
      _makeCategory('Investments', AssetPaths.categoryInvestments, 0xFF14B8A6, 2, 15),
    ];

    await _isar.writeTxn(() async {
      await _isar.categoryModels.putAll(defaults);
    });
  }

  /// Helper to construct a default category.
  CategoryModel _makeCategory(
    String name,
    String icon,
    int color,
    int type,
    int sortOrder,
  ) {
    return CategoryModel()
      ..name = name
      ..icon = icon
      ..color = color
      ..type = type
      ..isCustom = false
      ..sortOrder = sortOrder
      ..createdAt = DateTime.now();
  }

  // ── REAL-TIME STREAM ─────────────────────────────────────────────────────

  /// Watches the entire category collection for any changes.
  Stream<void> watchAll() {
    return _isar.categoryModels.watchLazy();
  }
}
