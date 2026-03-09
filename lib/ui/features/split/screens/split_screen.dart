import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/split_model.dart';
import '../providers/split_providers.dart';

/// Split expenses screen showing active splits, balances, and history.
class SplitScreen extends ConsumerStatefulWidget {
  const SplitScreen({super.key});

  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = ref.watch(splitSummaryProvider);
    final activeSplits = ref.watch(activeSplitsProvider);
    final settledSplits = ref.watch(settledSplitsProvider);
    final balances = ref.watch(participantBalancesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.pushNamed(RouteNames.addSplit),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Balances'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Summary Header ──
          _SummaryHeader(summary: summary)
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.1, end: 0),

          // ── Tab Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ActiveSplitsTab(splits: activeSplits),
                _BalancesTab(balances: balances),
                _HistoryTab(splits: settledSplits),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.addSplit),
        icon: const Icon(Icons.call_split_rounded),
        label: const Text('Split'),
      ),
    );
  }
}

// ── Summary Header ──────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final SplitSummary summary;
  const _SummaryHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outstanding',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '\$${summary.totalOwedToYou.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatChip(
                label: '${summary.activeSplits} active',
                color: colors.primary,
              ),
              const SizedBox(height: AppSpacing.xs),
              _StatChip(
                label: '${summary.totalSplits} total',
                color: colors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

// ── Active Splits Tab ───────────────────────────────────────────────────────

class _ActiveSplitsTab extends StatelessWidget {
  final List<SplitModel> splits;
  const _ActiveSplitsTab({required this.splits});

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) {
      return _EmptyState(
        svg: AssetPaths.emptySplits,
        title: 'No active splits',
        subtitle: 'Split an expense with friends to get started.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: splits.length,
      itemBuilder: (context, index) {
        final split = splits[index];
        return _SplitCard(split: split)
            .animate(delay: (index * 60).ms)
            .fadeIn(duration: 300.ms)
            .slideX(begin: 0.05, end: 0);
      },
    );
  }
}

class _SplitCard extends ConsumerWidget {
  final SplitModel split;
  const _SplitCard({required this.split});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final settled = split.participants.where((p) => p.isSettled).length;
    final total = split.participants.length;
    final progress = total > 0 ? settled / total : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => _showSplitDetail(context, ref, split),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _splitMethodIcon(split.splitMethod),
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      split.description,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '\$${split.totalAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Participant avatars
              Row(
                children: [
                  ...split.participants.take(5).map((p) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: p.isSettled
                              ? colors.primary.withOpacity(0.3)
                              : colors.surfaceContainerHighest,
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: p.isSettled
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )),
                  if (split.participants.length > 5)
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: colors.surfaceContainerHighest,
                      child: Text(
                        '+${split.participants.length - 5}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '$settled/$total settled',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: colors.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    progress >= 1.0 ? Colors.green : colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _splitMethodIcon(int method) {
    switch (method) {
      case 0:
        return Icons.drag_handle_rounded; // equal
      case 1:
        return Icons.pin_rounded; // exact
      case 2:
        return Icons.percent_rounded; // percentage
      default:
        return Icons.call_split_rounded;
    }
  }

  void _showSplitDetail(
      BuildContext context, WidgetRef ref, SplitModel split) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(split.description,
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Total: \$${split.totalAmount.toStringAsFixed(2)} | ${_splitMethodLabel(split.splitMethod)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const Divider(height: AppSpacing.xl),
            ...split.participants.map((p) => _ParticipantTile(
                  participant: p,
                  splitId: split.id,
                  ref: ref,
                )),
          ],
        ),
      ),
    );
  }

  String _splitMethodLabel(int method) {
    switch (method) {
      case 0:
        return 'Equal split';
      case 1:
        return 'Exact amounts';
      case 2:
        return 'Percentage';
      default:
        return 'Split';
    }
  }
}

class _ParticipantTile extends StatelessWidget {
  final SplitParticipant participant;
  final int splitId;
  final WidgetRef ref;

  const _ParticipantTile({
    required this.participant,
    required this.splitId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: participant.isSettled
            ? Colors.green.withOpacity(0.15)
            : colors.primaryContainer,
        child: participant.isSettled
            ? const Icon(Icons.check_rounded, color: Colors.green, size: 20)
            : Text(
                participant.name.isNotEmpty
                    ? participant.name[0].toUpperCase()
                    : '?',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
      ),
      title: Text(participant.name),
      subtitle: participant.contact != null
          ? Text(participant.contact!,
              style: theme.textTheme.bodySmall)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\$${participant.amount.toStringAsFixed(2)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: participant.isSettled ? Colors.green : null,
              decoration:
                  participant.isSettled ? TextDecoration.lineThrough : null,
            ),
          ),
          if (!participant.isSettled) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: Icon(Icons.check_circle_outline_rounded,
                  color: colors.primary, size: 22),
              onPressed: () => _markSettled(context),
              tooltip: 'Mark as settled',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markSettled(BuildContext context) async {
    final repo = ref.read(splitRepositoryProvider);
    final split = await repo.getById(splitId);
    if (split == null) return;

    final idx = split.participants
        .indexWhere((p) => p.name == participant.name);
    if (idx != -1) {
      split.participants[idx].isSettled = true;
      split.isFullySettled =
          split.participants.every((p) => p.isSettled);
      await repo.update(split);
    }
  }
}

// ── Balances Tab ────────────────────────────────────────────────────────────

class _BalancesTab extends StatelessWidget {
  final List<ParticipantBalance> balances;
  const _BalancesTab({required this.balances});

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return _EmptyState(
        svg: AssetPaths.emptySplits,
        title: 'No balances yet',
        subtitle: 'Split expenses to see who owes what.',
      );
    }

    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: balances.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final b = balances[index];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          leading: CircleAvatar(
            backgroundColor: b.isSettled
                ? Colors.green.withOpacity(0.15)
                : theme.colorScheme.errorContainer,
            child: Text(
              b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: b.isSettled
                    ? Colors.green
                    : theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          title: Text(b.name),
          subtitle: Text(
            '${b.splitCount} split${b.splitCount != 1 ? 's' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                b.isSettled
                    ? 'Settled'
                    : '\$${b.outstanding.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: b.isSettled ? Colors.green : theme.colorScheme.error,
                ),
              ),
              if (!b.isSettled)
                Text(
                  'owes you',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── History Tab ─────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List<SplitModel> splits;
  const _HistoryTab({required this.splits});

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) {
      return _EmptyState(
        svg: AssetPaths.emptySplits,
        title: 'No settled splits',
        subtitle: 'Settled splits will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: splits.length,
      itemBuilder: (context, index) {
        final split = splits[index];
        final theme = Theme.of(context);
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.15),
              child: const Icon(Icons.check_rounded,
                  color: Colors.green, size: 20),
            ),
            title: Text(split.description),
            subtitle: Text(
              '${split.participants.length} people | \$${split.totalAmount.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Text(
              _formatDate(split.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

// ── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String svg;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.svg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(svg, height: 120),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
