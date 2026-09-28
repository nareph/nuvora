import 'package:gymgenius/domain/entities/food_item.dart';
import 'package:gymgenius/domain/entities/logged_food_portion.dart';
import 'package:gymgenius/domain/entities/meal.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/models/meal_template.dart';
import 'package:gymgenius/domain/entities/meal_portion_option.dart';

/// Builds [NutritionLog] entries for the four-tier logging system:
/// 1. suggested meal as-is, 2. saved database meal, 3. food
/// composition, 4. manual macros.
class MealLogBuilder {
  const MealLogBuilder();

  /// Tier 1 — log a suggested plan meal exactly as proposed.
  NutritionLog fromPlanMeal({
    required Meal meal,
    required String userId,
    DateTime? loggedAt,
    String? note,
  }) {
    final now = loggedAt ?? DateTime.now();
    final templateId = _extractTemplateId(meal.id);

    return NutritionLog(
      id: _newId(userId, now),
      userId: userId,
      name: meal.name,
      source: NutritionLogSource.template,
      mealType: meal.type,
      macros: meal.macros,
      loggedAt: now,
      templateId: templateId,
      planMealId: meal.id,
      note: note,
    );
  }

  /// Tier 2 — log an existing [MealTemplate] chosen from the full food
  /// knowledge base catalog (not necessarily suggested for today).
  ///
  /// When [portion] is provided, the template's reference macros are scaled
  /// through [MealTemplate.macrosForPortion]. When it is omitted, the
  /// reference [MealTemplate.baseMacros] are preserved for backwards
  /// compatibility.
  ///
  /// The human portion label is intentionally not persisted yet: the current
  /// [NutritionLog] schema already stores the normalized nutritional result
  /// and [templateId]. A future persistence change can add an explicit
  /// portion id/label when that becomes necessary.
  NutritionLog fromMealTemplate({
    required MealTemplate template,
    required MealType mealType,
    required String userId,
    MealPortionOption? portion,
    DateTime? loggedAt,
    String? note,
  }) {
    final now = loggedAt ?? DateTime.now();
    final macros = portion == null
        ? template.baseMacros
        : template.macrosForPortion(portion);

    return NutritionLog(
      id: _newId(userId, now),
      userId: userId,
      name: template.name,
      source: NutritionLogSource.database,
      mealType: mealType,
      macros: macros,
      loggedAt: now,
      templateId: template.id,
      note: note,
    );
  }

  /// Tier 3 — compose a meal from individual food portions.
  NutritionLog fromFoodPortions({
    required String userId,
    required String name,
    required MealType mealType,
    required List<LoggedFoodPortion> portions,
    required List<FoodItem> availableFoods,
    DateTime? loggedAt,
    String? note,
  }) {
    final validPortions = portions.where((p) => p.isValid).toList();
    final macros = computeMacrosFromPortions(validPortions, availableFoods);
    final now = loggedAt ?? DateTime.now();

    return NutritionLog(
      id: _newId(userId, now),
      userId: userId,
      name: name.trim().isEmpty ? 'Custom meal' : name.trim(),
      source: NutritionLogSource.composed,
      mealType: mealType,
      macros: macros,
      loggedAt: now,
      portions: validPortions,
      note: note,
    );
  }

  /// Tier 4 — manual free-form entry with user-supplied macros.
  NutritionLog fromManual({
    required String userId,
    required String name,
    required MealType mealType,
    required MacroTargets macros,
    DateTime? loggedAt,
    String? note,
  }) {
    final now = loggedAt ?? DateTime.now();

    return NutritionLog(
      id: _newId(userId, now),
      userId: userId,
      name: name.trim().isEmpty ? 'Manual meal' : name.trim(),
      source: NutritionLogSource.manual,
      mealType: mealType,
      macros: macros,
      loggedAt: now,
      note: note,
    );
  }

  /// Sums macros from food portions using the knowledge base.
  MacroTargets computeMacrosFromPortions(
    List<LoggedFoodPortion> portions,
    List<FoodItem> availableFoods,
  ) {
    final foodById = {for (final f in availableFoods) f.id: f};
    var calories = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;

    for (final portion in portions) {
      final food = foodById[portion.foodId];
      if (food == null) continue;
      calories += food.caloriesForGrams(portion.grams);
      protein += food.proteinForGrams(portion.grams);
      carbs += food.carbsForGrams(portion.grams);
      fat += food.fatForGrams(portion.grams);
    }

    return MacroTargets(
      calories: calories.round().clamp(1, 10000),
      proteinG: protein.round().clamp(0, 1000),
      carbsG: carbs.round().clamp(0, 2000),
      fatG: fat.round().clamp(0, 1000),
    );
  }

  /// Aggregates macros across multiple logs for a day.
  MacroTargets sumLoggedMacros(Iterable<NutritionLog> logs) {
    var calories = 0;
    var protein = 0;
    var carbs = 0;
    var fat = 0;

    for (final log in logs) {
      calories += log.macros.calories;
      protein += log.macros.proteinG;
      carbs += log.macros.carbsG;
      fat += log.macros.fatG;
    }

    return MacroTargets(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
    );
  }

  String _newId(String userId, DateTime loggedAt) =>
      '${userId}_meal_${loggedAt.millisecondsSinceEpoch}';

  /// Plan meals use ids like `cm_meal_rice_chicken_breakfast`.
  String? _extractTemplateId(String planMealId) {
    final slotSuffixes = MealType.values.map((t) => '_${t.value}').toList();
    for (final suffix in slotSuffixes) {
      if (planMealId.endsWith(suffix)) {
        return planMealId.substring(0, planMealId.length - suffix.length);
      }
    }
    return planMealId;
  }
}
