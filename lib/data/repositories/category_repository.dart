import 'package:drift/drift.dart';

import '../../config/constants/category_catalog.dart';
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
    await (_d.update(
      _d.categories,
    )..where((c) => c.id.equals(category.id))).write(
      CategoriesCompanion(
        name: Value(category.name),
        icon: Value(category.icon),
        color: Value(category.color),
        type: Value(category.type),
        isCustom: Value(category.isCustom),
        parentId: Value(category.parentId),
        sortOrder: Value(category.sortOrder),
      ),
    );
  }

  Future<void> delete(int id) async {
    await (_d.delete(_d.categories)..where((c) => c.id.equals(id))).go();
  }

  Future<CategoryModel?> getById(int id) async {
    final row = await (_d.select(
      _d.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<CategoryModel>> getAll() async {
    final rows =
        await (_d.select(_d.categories)..orderBy([
              (c) => OrderingTerm.asc(c.sortOrder),
              (c) => OrderingTerm.asc(c.name),
            ]))
            .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<CategoryModel>> getByType(int type) async {
    final rows =
        await (_d.select(_d.categories)
              ..where((c) => c.type.equals(type) | c.type.equals(2))
              ..orderBy([
                (c) => OrderingTerm.asc(c.sortOrder),
                (c) => OrderingTerm.asc(c.name),
              ]))
            .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<CategoryModel>> getCustom() async {
    final rows = await (_d.select(
      _d.categories,
    )..where((c) => c.isCustom.equals(true))).get();
    return rows.map(_fromRow).toList();
  }

  Future<bool> exists(String name, int type) async {
    final row =
        await (_d.select(_d.categories)
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

  Future<void> seedMissingDefaults() async {
    final existing = await getAll();
    final existingKeys = {
      for (final category in existing)
        '${category.type}:${category.name.trim().toLowerCase()}',
    };
    final offset = existing.length;

    for (final entry in _defaultCategories()) {
      final key = '${entry.type}:${entry.name.trim().toLowerCase()}';
      if (existingKeys.contains(key)) continue;

      await add(
        CategoryModel(
          name: entry.name,
          icon: entry.icon,
          color: entry.color,
          type: entry.type,
          isCustom: entry.isCustom,
          parentId: entry.parentId,
          sortOrder: entry.sortOrder + offset,
          createdAt: entry.createdAt,
        ),
      );
    }
  }

  List<CategoryModel> _defaultCategories() {
    final now = DateTime.now();
    return CategoryCatalog.defaults
        .asMap()
        .entries
        .map(
          (entry) => entry.value.toModel(sortOrder: entry.key, createdAt: now),
        )
        .toList();
  }

  Stream<void> watchAll() => _d.select(_d.categories).watch().map((_) {});
}
