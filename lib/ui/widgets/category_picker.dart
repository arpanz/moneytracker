import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/di/providers.dart';
import '../../config/constants/category_catalog.dart';
import '../../config/theme/spacing.dart';
import '../../config/theme/theme_extensions.dart';
import '../../domain/models/category_model.dart';

/// A compact horizontally-scrollable chip row for picking a category,
/// with a trailing "+ New" chip that opens an inline creation bottom-sheet.
///
/// Replace any full-grid category picker with this widget.
class CategoryPickerRow extends ConsumerStatefulWidget {
  /// Currently selected category model (may be null if nothing selected).
  final CategoryModel? selected;

  /// Optional category name used to restore selection when editing.
  final String? selectedCategoryName;

  /// Transaction type: 0=income, 1=expense. Mapped to category type internally.
  final int transactionType;

  /// Called when the user taps a category chip.
  final ValueChanged<CategoryModel> onSelected;

  const CategoryPickerRow({
    super.key,
    required this.selected,
    this.selectedCategoryName,
    required this.transactionType,
    required this.onSelected,
  });

  @override
  ConsumerState<CategoryPickerRow> createState() => _CategoryPickerRowState();
}

class _CategoryPickerRowState extends ConsumerState<CategoryPickerRow> {
  static const int _previewLimit = 4;

  final List<CategoryModel> _localCustom = [];
  String? _restoredCategoryName;

  static const _svgFallbackIcon = Icons.category_rounded;

  // Common FontAwesome icons available for custom categories.
  static const _iconOptions = [
    (icon: FontAwesomeIcons.utensils, label: 'Food'),
    (icon: FontAwesomeIcons.car, label: 'Car'),
    (icon: FontAwesomeIcons.cartShopping, label: 'Shopping'),
    (icon: FontAwesomeIcons.fileInvoiceDollar, label: 'Bills'),
    (icon: FontAwesomeIcons.film, label: 'Entertainment'),
    (icon: FontAwesomeIcons.heartPulse, label: 'Health'),
    (icon: FontAwesomeIcons.graduationCap, label: 'Education'),
    (icon: FontAwesomeIcons.plane, label: 'Travel'),
    (icon: FontAwesomeIcons.gift, label: 'Gifts'),
    (icon: FontAwesomeIcons.sackDollar, label: 'Salary'),
    (icon: FontAwesomeIcons.laptop, label: 'Freelance'),
    (icon: FontAwesomeIcons.chartLine, label: 'Invest'),
    (icon: FontAwesomeIcons.houseChimney, label: 'Rent'),
    (icon: FontAwesomeIcons.basketShopping, label: 'Grocery'),
    (icon: FontAwesomeIcons.paw, label: 'Pets'),
    (icon: FontAwesomeIcons.tv, label: 'Subscriptions'),
    (icon: FontAwesomeIcons.shieldHeart, label: 'Insurance'),
    (icon: FontAwesomeIcons.soap, label: 'Personal Care'),
    (icon: FontAwesomeIcons.bolt, label: 'Energy'),
    (icon: FontAwesomeIcons.gasPump, label: 'Fuel'),
    (icon: FontAwesomeIcons.droplet, label: 'Water'),
    (icon: FontAwesomeIcons.wifi, label: 'Internet'),
    (icon: FontAwesomeIcons.mobileScreen, label: 'Phone'),
    (icon: FontAwesomeIcons.dumbbell, label: 'Gym'),
    (icon: FontAwesomeIcons.mugHot, label: 'Coffee'),
    (icon: FontAwesomeIcons.gamepad, label: 'Gaming'),
    (icon: FontAwesomeIcons.music, label: 'Music'),
    (icon: FontAwesomeIcons.bookOpen, label: 'Books'),
    (icon: FontAwesomeIcons.baby, label: 'Baby'),
    (icon: FontAwesomeIcons.shirt, label: 'Clothes'),
    (icon: FontAwesomeIcons.house, label: 'Home'),
    (icon: FontAwesomeIcons.fileInvoice, label: 'Taxes'),
    (icon: FontAwesomeIcons.briefcase, label: 'Business'),
    (icon: FontAwesomeIcons.coins, label: 'Bonus'),
    (icon: FontAwesomeIcons.toolbox, label: 'Repairs'),
    (icon: FontAwesomeIcons.circleQuestion, label: 'Other'),
    (icon: FontAwesomeIcons.moneyBill, label: 'Cash'),
  ];

  int get _categoryType {
    switch (widget.transactionType) {
      case 0:
        return 1;
      case 1:
        return 0;
      default:
        return 2;
    }
  }

  void _showCreateSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    FaIconData selectedIcon = FontAwesomeIcons.circleQuestion;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                top: Spacing.lg,
                left: Spacing.md,
                right: Spacing.md,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            ctx,
                          ).colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: Radii.borderFull,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      'New Category',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),

                    // ── Name Field ──
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Category name',
                        border: OutlineInputBorder(
                          borderRadius: Radii.borderMd,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),

                    // ── Icon Picker ──
                    Text(
                      'Choose an icon',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    SizedBox(
                      height: 200,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              mainAxisSpacing: Spacing.sm,
                              crossAxisSpacing: Spacing.sm,
                              childAspectRatio: 1,
                            ),
                        itemCount: _iconOptions.length,
                        itemBuilder: (_, i) {
                          final opt = _iconOptions[i];
                          final isSel = selectedIcon == opt.icon;
                          return GestureDetector(
                            onTap: () =>
                                setSheet(() => selectedIcon = opt.icon),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? Theme.of(ctx).colorScheme.primary
                                          .withValues(alpha: 0.15)
                                    : Theme.of(
                                        ctx,
                                      ).colorScheme.surfaceContainerLow,
                                borderRadius: Radii.borderMd,
                                border: Border.all(
                                  color: isSel
                                      ? Theme.of(ctx).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: FaIcon(
                                  opt.icon,
                                  size: 20,
                                  color: isSel
                                      ? Theme.of(ctx).colorScheme.primary
                                      : Theme.of(ctx).colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: Spacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          await _submit(ctx, nameCtrl.text, selectedIcon);
                        },
                        child: const Text('Create & Select'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submit(
    BuildContext sheetCtx,
    String rawName,
    FaIconData chosenIcon,
  ) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      _showMessage('Enter a category name.');
      return;
    }

    final categoryRepo = ref.read(categoryRepositoryProvider);
    final existing = await categoryRepo.getByType(_categoryType);
    final normalizedName = name.toLowerCase();
    final duplicate = existing.any(
      (category) => category.name.trim().toLowerCase() == normalizedName,
    );

    if (duplicate) {
      _showMessage('A category named "$name" already exists.');
      return;
    }

    final newCat = CategoryModel()
      ..name = name
      ..icon = _assetPathFor(chosenIcon)
      ..color = 0xFF9E9E9E
      ..type = _categoryType
      ..isCustom = true
      ..sortOrder = 999
      ..createdAt = DateTime.now();

    try {
      final newId = await categoryRepo.add(newCat);
      newCat.id = newId;

      // Invalidate providers so the chip row refreshes from DB.
      ref.invalidate(_categoriesProvider);

      if (mounted) {
        setState(() => _localCustom.add(newCat));
        widget.onSelected(newCat);
      }
      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
    } catch (_) {
      _showMessage('Could not create category. Try a different name.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _iconLabelFor(FaIconData icon) {
    for (final opt in _iconOptions) {
      if (opt.icon == icon) return opt.label.toLowerCase();
    }
    return 'other';
  }

  String _assetPathFor(FaIconData icon) {
    return CategoryCatalog.assetPathForKeyword(_iconLabelFor(icon));
  }

  CategoryModel? _restoreSelectionIfNeeded(List<CategoryModel> categories) {
    if (widget.selected != null) {
      return widget.selected;
    }

    final categoryName = widget.selectedCategoryName;
    if (categoryName == null || _restoredCategoryName == categoryName) {
      return null;
    }

    final match = categories.where((c) => c.name == categoryName).firstOrNull;
    if (match == null) {
      return null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _restoredCategoryName == categoryName) return;
      setState(() => _restoredCategoryName = categoryName);
      if (widget.selected?.id != match.id) {
        widget.onSelected(match);
      }
    });

    return match;
  }

  List<CategoryModel> _previewCategories(
    List<CategoryModel> categories,
    CategoryModel? selected,
  ) {
    final preview = <CategoryModel>[];

    if (selected != null) {
      preview.add(selected);
    }

    for (final category in categories) {
      final alreadyAdded = preview.any((item) => item.id == category.id);
      if (alreadyAdded) continue;
      preview.add(category);
      if (preview.length == _previewLimit) {
        break;
      }
    }

    return preview.take(_previewLimit).toList();
  }

  Color _categoryColorFor(
    CategoryModel category,
    ThemeData theme,
    CheddarColors? cheddarColors,
  ) {
    return cheddarColors?.categoryColors[category.name.toLowerCase()] ??
        Color(category.color);
  }

  void _showAllCategoriesDialog(
    BuildContext context,
    List<CategoryModel> categories,
    CategoryModel? selected,
    CheddarColors? cheddarColors,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final dialogHeight = (MediaQuery.of(dialogContext).size.height * 0.62)
            .clamp(280.0, 520.0)
            .toDouble();

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.lg,
          ),
          shape: RoundedRectangleBorder(borderRadius: Radii.borderLg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.md,
              Spacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose Category',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                Text(
                  'Pick a category or create a new one.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                SizedBox(
                  width: double.infinity,
                  height: dialogHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 380
                          ? 4
                          : 3;

                      return GridView.builder(
                        itemCount: categories.length + 1,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: Spacing.sm,
                          crossAxisSpacing: Spacing.sm,
                          childAspectRatio: 0.9,
                        ),
                        itemBuilder: (context, index) {
                          if (index == categories.length) {
                            return _buildActionTile(
                              context: context,
                              icon: Icons.add_rounded,
                              label: 'New',
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                Future<void>.delayed(Duration.zero, () {
                                  if (mounted) {
                                    _showCreateSheet(this.context);
                                  }
                                });
                              },
                            );
                          }

                          final category = categories[index];
                          final isSelected = selected?.id == category.id;

                          return _buildCategoryTile(
                            context: context,
                            category: category,
                            categoryColor: _categoryColorFor(
                              category,
                              theme,
                              cheddarColors,
                            ),
                            isSelected: isSelected,
                            onTap: () {
                              widget.onSelected(category);
                              Navigator.of(dialogContext).pop();
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryTile({
    required BuildContext context,
    required CategoryModel category,
    required Color categoryColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.borderMd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? categoryColor.withValues(alpha: 0.14)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: Radii.borderMd,
            border: Border.all(
              color: isSelected
                  ? categoryColor
                  : theme.colorScheme.outline.withValues(alpha: 0.16),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: categoryColor.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: isSelected
                        ? categoryColor.withValues(alpha: 0.4)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.scrim.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.28
                            : 0.04,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SvgPicture.asset(
                    category.icon,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) =>
                        Icon(_svgFallbackIcon, size: 22, color: categoryColor),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                category.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.borderMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: Radii.borderMd,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.28),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>();
    final categoriesAsync = ref.watch(_categoriesProvider(_categoryType));

    return categoriesAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (dbCats) {
        // Merge DB categories with locally created ones, dedup by name.
        final existing = dbCats.map((c) => c.name).toSet();
        final all = [
          ...dbCats,
          ..._localCustom.where((c) => !existing.contains(c.name)),
        ];
        final effectiveSelected = _restoreSelectionIfNeeded(all);
        final preview = _previewCategories(all, effectiveSelected);
        final hasMore = all.length > preview.length;

        return LayoutBuilder(
          builder: (context, constraints) {
            const columns = 3;
            final tileWidth =
                (constraints.maxWidth - (Spacing.sm * (columns - 1))) / columns;

            return Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                ...preview.map((category) {
                  return SizedBox(
                    width: tileWidth,
                    child: _buildCategoryTile(
                      context: context,
                      category: category,
                      categoryColor: _categoryColorFor(
                        category,
                        theme,
                        cheddarColors,
                      ),
                      isSelected: effectiveSelected?.id == category.id,
                      onTap: () => widget.onSelected(category),
                    ),
                  );
                }),
                if (hasMore)
                  SizedBox(
                    width: tileWidth,
                    child: _buildActionTile(
                      context: context,
                      icon: Icons.grid_view_rounded,
                      label: 'More',
                      onTap: () => _showAllCategoriesDialog(
                        context,
                        all,
                        effectiveSelected,
                        cheddarColors,
                      ),
                    ),
                  ),
                SizedBox(
                  width: tileWidth,
                  child: _buildActionTile(
                    context: context,
                    icon: Icons.add_rounded,
                    label: 'New',
                    onTap: () => _showCreateSheet(context),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Internal provider scoped to this file.
final _categoriesProvider = FutureProvider.family<List<CategoryModel>, int>((
  ref,
  type,
) async {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getByType(type);
});
