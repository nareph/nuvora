import 'package:gymgenius/domain/entities/meal_portion_option.dart';
import 'package:gymgenius/domain/enums/budget_level.dart';
import 'package:gymgenius/domain/enums/meal_objective.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';

/// Template meal used by the MealPlanner (before portion scaling).
class MealTemplate {
  final String id;
  final String name;
  final MealObjective objective;
  final List<String> ingredientIds;
  final List<String> ingredientNames;
  final MacroTargets baseMacros;
  final BudgetLevel minBudget;
  final List<String> allergens;
  final List<String> tags;

  /// Explicit portion choices for this meal.
  ///
  /// When a dataset entry does not define its own options, the planner/UI
  /// can use [effectivePortionOptions] so all existing meals immediately
  /// support human-friendly portions.
  final List<MealPortionOption> portionOptions;

  const MealTemplate({
    required this.id,
    required this.name,
    required this.objective,
    required this.ingredientIds,
    required this.ingredientNames,
    required this.baseMacros,
    this.minBudget = BudgetLevel.low,
    this.allergens = const [],
    this.tags = const [],
    this.portionOptions = const [],
  });

  /// Returns explicit portion options when provided, otherwise the
  /// shared default meal portion scale.
  List<MealPortionOption> get effectivePortionOptions {
    if (portionOptions.isNotEmpty) {
      return List.unmodifiable(portionOptions);
    }

    return const [
      MealPortionOption(
        id: 'small',
        label: 'Small portion',
        multiplier: 0.75,
      ),
      MealPortionOption(
        id: 'standard',
        label: 'Standard portion',
        multiplier: 1.0,
      ),
      MealPortionOption(
        id: 'large',
        label: 'Large portion',
        multiplier: 1.25,
      ),
    ];
  }

  /// Scales the reference meal macros according to the selected portion.
  ///
  /// [baseMacros] always represents the standard/reference portion.
  MacroTargets macrosForPortion(MealPortionOption portion) {
    return MacroTargets(
      calories: (baseMacros.calories * portion.multiplier).round(),
      proteinG: (baseMacros.proteinG * portion.multiplier).round(),
      carbsG: (baseMacros.carbsG * portion.multiplier).round(),
      fatG: (baseMacros.fatG * portion.multiplier).round(),
    );
  }

  MealTemplate copyWith({
    String? id,
    String? name,
    MealObjective? objective,
    List<String>? ingredientIds,
    List<String>? ingredientNames,
    MacroTargets? baseMacros,
    BudgetLevel? minBudget,
    List<String>? allergens,
    List<String>? tags,
    List<MealPortionOption>? portionOptions,
  }) {
    return MealTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      objective: objective ?? this.objective,
      ingredientIds: ingredientIds ?? this.ingredientIds,
      ingredientNames: ingredientNames ?? this.ingredientNames,
      baseMacros: baseMacros ?? this.baseMacros,
      minBudget: minBudget ?? this.minBudget,
      allergens: allergens ?? this.allergens,
      tags: tags ?? this.tags,
      portionOptions: portionOptions ?? this.portionOptions,
    );
  }
}
