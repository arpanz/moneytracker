import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/di/providers.dart';
import '../../config/constants/asset_paths.dart';
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

  /// Transaction type: 0=income, 1=expense. Drives which categories are shown.
  final int transactionType;

  /// Called when the user taps a category chip.
  final ValueChanged<CategoryModel> onSelected;

  const CategoryPickerRow({
    super.key,
    required this.selected,
    required this.transactionType,
    required this.onSelected,
  });

  @override
  ConsumerState<CategoryPickerRow> createState() => _CategoryPickerRowState();
}

class _CategoryPickerRowState extends ConsumerState<CategoryPickerRow> {
  final List<CategoryModel> _localCustom = [];

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
    (icon: FontAwesomeIcons.bolt, label: 'Energy'),
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
    (icon: FontAwesomeIcons.toolbox, label: 'Repairs'),
    (icon: FontAwesomeIcons.circleQuestion, label: 'Other'),
    (icon: FontAwesomeIcons.moneyBill, label: 'Cash'),
  ];

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
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.2),
                          borderRadius: Radii.borderFull,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      'New Category',
                      style:
                          Theme.of(ctx).textTheme.titleLarge?.copyWith(
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
                                    ? Theme.of(ctx)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.15)
                                    : Theme.of(ctx)
                                        .colorScheme
                                        .surfaceContainerLow,
                                borderRadius: Radii.borderMd,
                                border: Border.all(
                                  color: isSel
                                      ? Theme.of(ctx).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FaIcon(
                                    opt.icon,
                                    size: 20,
                                    color: isSel
                                        ? Theme.of(ctx).colorScheme.primary
                                        : Theme.of(ctx)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    opt.label,
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: isSel
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isSel
                                          ? Theme.of(ctx).colorScheme.primary
                                          : Theme.of(ctx)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
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
                          await _submit(
                              ctx, nameCtrl.text, selectedIcon);
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
      BuildContext sheetCtx, String rawName, FaIconData chosenIcon) async {
    final name = rawName.trim();
    if (name.isEmpty) return;

    // Map the chosen FaIconData to a consistent string key for storage.
    // We store it as the FA icon name string so it can be re-rendered later.
    final iconKey = _iconLabelFor(chosenIcon);

    final categoryRepo = ref.read(categoryRepositoryProvider);
    final newCat = CategoryModel()
      ..name = name
      // Store a placeholder SVG path; icon rendering uses iconKey stored in
      // a separate field if available, else falls back to AssetPaths.categoryDefault.
      ..icon = AssetPaths.categoryDefault
      ..color = 0xFF9E9E9E
      ..type = widget.transactionType
      ..isCustom = true
      ..sortOrder = 999
      ..createdAt = DateTime.now();

    await categoryRepo.save(newCat);

    // Invalidate providers so the chip row refreshes from DB.
    ref.invalidate(_categoriesProvider);

    if (mounted) {
      setState(() => _localCustom.add(newCat));
      widget.onSelected(newCat);
    }
    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
  }

  String _iconLabelFor(FaIconData icon) {
    for (final opt in _iconOptions) {
      if (opt.icon == icon) return opt.label.toLowerCase();
    }
    return 'other';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>();
    final categoriesAsync = ref.watch(_categoriesProvider
        .call(widget.transactionType));

    return categoriesAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (dbCats) {
        // Merge DB categories with locally created ones, dedup by name.
        final existing = dbCats.map((c) => c.name).toSet();
        final all = [
          ...dbCats,
          ..._localCustom.where((c) => !existing.contains(c.name)),
        ];

        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: all.length + 1, // +1 for the '+ New' chip
            separatorBuilder: (_, __) =>
                const SizedBox(width: Spacing.xs),
            itemBuilder: (context, index) {
              // Trailing '+ New' chip
              if (index == all.length) {
                return ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('New'),
                  onPressed: () => _showCreateSheet(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: Radii.borderFull,
                  ),
                );
              }

              final cat = all[index];
              final isSelected = widget.selected?.id == cat.id;
              final catColor = cheddarColors?.categoryColors[
                          cat.name.toLowerCase()] ??
                      theme.colorScheme.primary;

              return ChoiceChip(
                avatar: SvgPicture.asset(
                  cat.icon,
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(
                    isSelected
                        ? catColor
                        : theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                    BlendMode.srcIn,
                  ),
                ),
                label: Text(cat.name),
                selected: isSelected,
                onSelected: (_) => widget.onSelected(cat),
                selectedColor: catColor.withValues(alpha: 0.15),
                side: BorderSide(
                  color: isSelected
                      ? catColor
                      : theme.colorScheme.outline
                          .withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: Radii.borderFull,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Internal provider scoped to this file.
final _categoriesProvider =
    FutureProvider.family<List<CategoryModel>, int>((ref, type) async {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getByType(type);
});
