import 'package:flutter/material.dart';

import '../../domain/models/category_model.dart';
import 'asset_paths.dart';

class AppCategoryDefinition {
  final String name;
  final String assetPath;
  final int colorValue;
  final int type;
  final List<String> keywords;

  const AppCategoryDefinition({
    required this.name,
    required this.assetPath,
    required this.colorValue,
    required this.type,
    this.keywords = const [],
  });

  String get slug => name.toLowerCase().trim();

  Color get color => Color(colorValue);

  CategoryModel toModel({required int sortOrder, required DateTime createdAt}) {
    return CategoryModel(
      name: name,
      icon: assetPath,
      color: colorValue,
      type: type,
      sortOrder: sortOrder,
      createdAt: createdAt,
    );
  }
}

abstract final class CategoryCatalog {
  static const List<AppCategoryDefinition> defaults = [
    AppCategoryDefinition(
      name: 'Food',
      assetPath: AssetPaths.categoryFood,
      colorValue: 0xFFFF6B6B,
      type: 0,
      keywords: ['food', 'coffee', 'dining'],
    ),
    AppCategoryDefinition(
      name: 'Transport',
      assetPath: AssetPaths.categoryTransport,
      colorValue: 0xFF4ECDC4,
      type: 0,
      keywords: ['transport', 'car', 'commute'],
    ),
    AppCategoryDefinition(
      name: 'Shopping',
      assetPath: AssetPaths.categoryShopping,
      colorValue: 0xFFFFBE76,
      type: 0,
      keywords: ['shopping', 'clothes'],
    ),
    AppCategoryDefinition(
      name: 'Bills',
      assetPath: AssetPaths.categoryBills,
      colorValue: 0xFF6C5CE7,
      type: 0,
      keywords: ['bills'],
    ),
    AppCategoryDefinition(
      name: 'Entertainment',
      assetPath: AssetPaths.categoryEntertainment,
      colorValue: 0xFFFF9FF3,
      type: 0,
      keywords: ['entertainment', 'gaming', 'music'],
    ),
    AppCategoryDefinition(
      name: 'Health',
      assetPath: AssetPaths.categoryHealth,
      colorValue: 0xFF55E6C1,
      type: 0,
      keywords: ['health', 'gym'],
    ),
    AppCategoryDefinition(
      name: 'Education',
      assetPath: AssetPaths.categoryEducation,
      colorValue: 0xFF48DBFB,
      type: 0,
      keywords: ['education', 'books'],
    ),
    AppCategoryDefinition(
      name: 'Travel',
      assetPath: AssetPaths.categoryTravel,
      colorValue: 0xFFFFA502,
      type: 0,
      keywords: ['travel'],
    ),
    AppCategoryDefinition(
      name: 'Gifts',
      assetPath: AssetPaths.categoryGifts,
      colorValue: 0xFFFF6348,
      type: 0,
      keywords: ['gifts'],
    ),
    AppCategoryDefinition(
      name: 'Rent',
      assetPath: AssetPaths.categoryRent,
      colorValue: 0xFFFF4757,
      type: 0,
      keywords: ['rent'],
    ),
    AppCategoryDefinition(
      name: 'Groceries',
      assetPath: AssetPaths.categoryGroceries,
      colorValue: 0xFFA3CB38,
      type: 0,
      keywords: ['groceries', 'grocery'],
    ),
    AppCategoryDefinition(
      name: 'Pets',
      assetPath: AssetPaths.categoryPets,
      colorValue: 0xFFF8A5C2,
      type: 0,
      keywords: ['pets'],
    ),
    AppCategoryDefinition(
      name: 'Subscriptions',
      assetPath: AssetPaths.categorySubscriptions,
      colorValue: 0xFF7158E2,
      type: 0,
      keywords: ['subscriptions'],
    ),
    AppCategoryDefinition(
      name: 'Insurance',
      assetPath: AssetPaths.categoryInsurance,
      colorValue: 0xFF00B894,
      type: 0,
      keywords: ['insurance'],
    ),
    AppCategoryDefinition(
      name: 'Personal Care',
      assetPath: AssetPaths.categoryPersonalCare,
      colorValue: 0xFFFF8FAB,
      type: 0,
      keywords: ['personal care', 'care'],
    ),
    AppCategoryDefinition(
      name: 'Utilities',
      assetPath: AssetPaths.categoryUtilities,
      colorValue: 0xFF4361EE,
      type: 0,
      keywords: ['utilities', 'energy', 'water', 'internet', 'phone'],
    ),
    AppCategoryDefinition(
      name: 'Fuel',
      assetPath: AssetPaths.categoryFuel,
      colorValue: 0xFFFF9F1C,
      type: 0,
      keywords: ['fuel'],
    ),
    AppCategoryDefinition(
      name: 'Home',
      assetPath: AssetPaths.categoryHome,
      colorValue: 0xFF9B5DE5,
      type: 0,
      keywords: ['home', 'repairs'],
    ),
    AppCategoryDefinition(
      name: 'Childcare',
      assetPath: AssetPaths.categoryChildcare,
      colorValue: 0xFFFF99C8,
      type: 0,
      keywords: ['childcare', 'baby'],
    ),
    AppCategoryDefinition(
      name: 'Taxes',
      assetPath: AssetPaths.categoryTaxes,
      colorValue: 0xFF577590,
      type: 0,
      keywords: ['taxes'],
    ),
    AppCategoryDefinition(
      name: 'Other',
      assetPath: AssetPaths.categoryOther,
      colorValue: 0xFF9E9E9E,
      type: 0,
      keywords: ['other', 'transfer'],
    ),
    AppCategoryDefinition(
      name: 'Salary',
      assetPath: AssetPaths.categorySalary,
      colorValue: 0xFF2ED573,
      type: 1,
      keywords: ['salary', 'cash'],
    ),
    AppCategoryDefinition(
      name: 'Freelance',
      assetPath: AssetPaths.categoryFreelance,
      colorValue: 0xFF1DD1A1,
      type: 1,
      keywords: ['freelance'],
    ),
    AppCategoryDefinition(
      name: 'Investments',
      assetPath: AssetPaths.categoryInvestments,
      colorValue: 0xFF5352ED,
      type: 1,
      keywords: ['investments', 'invest'],
    ),
    AppCategoryDefinition(
      name: 'Bonus',
      assetPath: AssetPaths.categoryBonus,
      colorValue: 0xFF06D6A0,
      type: 1,
      keywords: ['bonus'],
    ),
    AppCategoryDefinition(
      name: 'Business',
      assetPath: AssetPaths.categoryBusiness,
      colorValue: 0xFF118AB2,
      type: 1,
      keywords: ['business'],
    ),
    AppCategoryDefinition(
      name: 'Rental Income',
      assetPath: AssetPaths.categoryRentalIncome,
      colorValue: 0xFF8338EC,
      type: 1,
      keywords: ['rental income', 'rental'],
    ),
  ];

  static String assetPathForName(String categoryName) {
    final normalized = categoryName.toLowerCase().trim();
    for (final definition in defaults) {
      if (definition.slug == normalized) {
        return definition.assetPath;
      }
    }
    return AssetPaths.categoryDefault;
  }

  static String assetPathForKeyword(String keyword) {
    final normalized = keyword.toLowerCase().trim();
    for (final definition in defaults) {
      if (definition.keywords.contains(normalized)) {
        return definition.assetPath;
      }
    }
    return AssetPaths.categoryDefault;
  }

  static Map<String, Color> buildColorMap() {
    return {
      for (final definition in defaults) definition.slug: definition.color,
    };
  }
}
