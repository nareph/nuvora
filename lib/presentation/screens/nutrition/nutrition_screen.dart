import 'package:flutter/material.dart';
import 'package:gymgenius/di/injection.dart';
import 'package:gymgenius/domain/entities/meal.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/entities/nutrition_plan.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/enums/nutrition_data_quality.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';
import 'package:gymgenius/domain/enums/nutrition_status.dart';
import 'package:gymgenius/presentation/viewmodels/nutrition_viewmodel.dart';
import 'package:gymgenius/presentation/widgets/nutrition/log_meal_sheet.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Nutrition detail screen with a meal timeline, replacement actions, and four-tier logging.

String formatCalories(NutritionLog log) {
  switch (log.dataQuality) {
    case NutritionDataQuality.standardized:
      return '${log.macros.calories} kcal';

    case NutritionDataQuality.estimated:
      return '~${log.macros.calories} kcal';

    case NutritionDataQuality.manual:
      return '${log.macros.calories} kcal';
  }
}

class NutritionScreen extends StatelessWidget {
  final NutritionPlan plan;

  const NutritionScreen({
    super.key,
    required this.plan,
  });

  static Route<void> route(NutritionPlan plan) {
    return MaterialPageRoute<void>(
      builder: (_) => NutritionScreen(plan: plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final vm = NutritionViewModel(
          plan: plan,
          userRepository: getIt(),
          healthRepository: getIt(),
          nutritionRepository: getIt(),
          nutritionEngine: getIt(),
        );
        Future.microtask(vm.load);
        return vm;
      },
      child: const _NutritionView(),
    );
  }
}

class _NutritionView extends StatelessWidget {
  const _NutritionView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NutritionViewModel>();
    Theme.of(context);
    final dateLabel = DateFormat.yMMMEd().format(vm.plan.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition'),
      ),
      floatingActionButton: vm.state == NutritionUiState.ready
          ? FloatingActionButton.extended(
              onPressed: () => showLogMealSheet(context: context, vm: vm),
              icon: const Icon(Icons.add),
              label: const Text('Log meal'),
            )
          : null,
      body: switch (vm.state) {
        NutritionUiState.loading ||
        NutritionUiState.initial =>
          const Center(child: CircularProgressIndicator()),
        NutritionUiState.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(vm.errorMessage ?? 'Unable to load nutrition'),
            ),
          ),
        NutritionUiState.ready => _NutritionContent(
            vm: vm,
            dateLabel: dateLabel,
          ),
      },
    );
  }
}

class _NutritionContent extends StatelessWidget {
  final NutritionViewModel vm;
  final String dateLabel;

  const _NutritionContent({
    required this.vm,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final suggestedLogs = <String>{
      for (final meal in vm.plan.meals) meal.id,
    };
    final standaloneLogs = vm.logs
        .where((log) =>
            log.planMealId == null || !suggestedLogs.contains(log.planMealId))
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          dateLabel,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          vm.plan.isTrainingDay ? 'Training day plan' : 'Rest day plan',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${vm.plan.country} · ${vm.plan.status.displayName}',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        _LoggedProgressCard(vm: vm),
        const SizedBox(height: 24),
        Text(
          'Today',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Your plan at a glance. Log what you actually eat — it does not have to match the suggestion.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        ...vm.plan.meals.map(
          (meal) => _TimelineMealCard(meal: meal, vm: vm),
        ),
        if (standaloneLogs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StandaloneLogsSection(logs: standaloneLogs, vm: vm),
        ],
        if (vm.plan.reasons.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Why these targets',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...vm.plan.reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Hydration target: ${((vm.plan.targets.waterMl ?? 0) / 1000).toStringAsFixed(1)} L',
          style: textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _LoggedProgressCard extends StatelessWidget {
  final NutritionViewModel vm;

  const _LoggedProgressCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final targets = vm.plan.targets;
    final logged = vm.loggedTotals;
    final progress = targets.calories > 0
        ? (logged.calories / targets.calories).clamp(0.0, 1.2)
        : 0.0;

    return Card(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logged ${logged.calories} / ${targets.calories} kcal',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress > 1 ? 1 : progress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MacroChip(
                  label: 'Protein',
                  logged: logged.proteinG,
                  target: targets.proteinG,
                ),
                const SizedBox(width: 8),
                _MacroChip(
                  label: 'Carbs',
                  logged: logged.carbsG,
                  target: targets.carbsG,
                ),
                const SizedBox(width: 8),
                _MacroChip(
                  label: 'Fat',
                  logged: logged.fatG,
                  target: targets.fatG,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              vm.logs.isEmpty
                  ? 'Nothing logged yet'
                  : 'Adherence: ${(vm.adherenceScore * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final int logged;
  final int target;

  const _MacroChip({
    required this.label,
    required this.logged,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$logged / ${target}g',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TimelineMealCard extends StatelessWidget {
  final Meal meal;
  final NutritionViewModel vm;

  const _TimelineMealCard({
    required this.meal,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final log = _matchingLog;
    final isLogged = log != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isLogged
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isLogged ? Icons.check_circle : _iconFor(meal.type),
                    color: isLogged
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.type.displayName,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meal.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(isLogged: isLogged),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${meal.macros.calories} kcal · P${meal.macros.proteinG} C${meal.macros.carbsG} F${meal.macros.fatG}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (meal.ingredients.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                meal.ingredients.join(' · '),
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (meal.timingNote != null) ...[
              const SizedBox(height: 6),
              Text(
                meal.timingNote!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed:
                        isLogged ? null : () => vm.logSuggestedMeal(meal),
                    icon: Icon(isLogged ? Icons.check : Icons.restaurant),
                    label: Text(isLogged ? 'Logged' : 'Log as eaten'),
                  ),
                ),
                const SizedBox(width: 8),
                if (vm.isChangingMeal(meal.id))
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: isLogged
                        ? null
                        : () async {
                            final changed = await vm.replaceSuggestedMeal(meal);
                            if (!context.mounted || changed) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No compatible replacement is available.',
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Change meal'),
                  ),
              ],
            ),
            if (!isLogged) ...[
              const SizedBox(height: 6),
              Text(
                'Change keeps this same meal slot and your nutrition targets.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (isLogged) ...[
              const SizedBox(height: 6),
              Text(
                'Actual: ${formatCalories(log)} · ${DateFormat.Hm().format(log.loggedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 2),
              Text(
                'Not logged yet',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  NutritionLog? get _matchingLog {
    for (final log in vm.logs) {
      if (log.planMealId == meal.id) return log;
    }
    return null;
  }

  IconData _iconFor(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return Icons.wb_sunny_outlined;
      case MealType.lunch:
        return Icons.lunch_dining_outlined;
      case MealType.dinner:
        return Icons.dinner_dining_outlined;
      case MealType.snack:
        return Icons.apple;
      case MealType.preWorkout:
        return Icons.bolt_outlined;
      case MealType.postWorkout:
        return Icons.sports_gymnastics;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final bool isLogged;

  const _StatusChip({required this.isLogged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isLogged
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isLogged ? 'Logged' : 'To do',
        style: theme.textTheme.labelMedium?.copyWith(
          color: isLogged
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StandaloneLogsSection extends StatelessWidget {
  final List<NutritionLog> logs;
  final NutritionViewModel vm;

  const _StandaloneLogsSection({
    required this.logs,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Also logged',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...logs.map(
              (log) => _StandaloneLogTile(log: log, vm: vm),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandaloneLogTile extends StatelessWidget {
  final NutritionLog log;
  final NutritionViewModel vm;

  const _StandaloneLogTile({
    required this.log,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading:
            Icon(_sourceIcon(log.source), color: theme.colorScheme.primary),
        title: Text(log.name),
        subtitle: Text(
          '${log.mealType.displayName} · '
          '${DateFormat.Hm().format(log.loggedAt)} · '
          '${formatCalories(log)}',
        ),
        trailing: IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => vm.deleteLog(log.id),
        ),
      ),
    );
  }

  IconData _sourceIcon(NutritionLogSource source) {
    switch (source) {
      case NutritionLogSource.template:
        return Icons.check_circle_outline;
      case NutritionLogSource.database:
        return Icons.restaurant_menu;
      case NutritionLogSource.composed:
        return Icons.tune;
      case NutritionLogSource.manual:
        return Icons.edit_note;
    }
  }
}
