import 'package:gymgenius/domain/entities/meal.dart';
import 'package:gymgenius/domain/entities/nutrition_adherence_snapshot.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/trackers/adherence_tracker.dart';

/// Converts raw nutrition logs into a compact, deterministic daily snapshot.
///
/// No persistence, UI, or Decision Engine dependencies belong here.
class NutritionAdherenceAnalyzer {
  final AdherenceTracker _adherenceTracker;

  const NutritionAdherenceAnalyzer({
    AdherenceTracker adherenceTracker = const AdherenceTracker(),
  }) : _adherenceTracker = adherenceTracker;

  NutritionAdherenceSnapshot analyze({
    required String userId,
    required DateTime date,
    required MacroTargets targets,
    required Iterable<Meal> plannedMeals,
    required Iterable<NutritionLog> logs,
  }) {
    final day = _dateOnly(date);
    final meals = plannedMeals.toList(growable: false);
    final expectedSlots = meals.map((meal) => meal.type).toSet();
    final dayLogs = logs
        .where((log) =>
            log.userId == userId && _dateOnly(log.loggedAt) == day)
        .toList(growable: false);

    var calories = 0;
    var protein = 0;
    var carbs = 0;
    var fat = 0;

    for (final log in dayLogs) {
      calories += log.macros.calories;
      protein += log.macros.proteinG;
      carbs += log.macros.carbsG;
      fat += log.macros.fatG;
    }

    final coveredSlots = dayLogs
        .map((log) => log.mealType)
        .where(expectedSlots.contains)
        .toSet();

    final missingSlots = expectedSlots
        .where((slot) => !coveredSlots.contains(slot))
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final coverage = expectedSlots.isEmpty
        ? 0.0
        : (coveredSlots.length / expectedSlots.length)
            .clamp(0.0, 1.0)
            .toDouble();

    final adherence = _adherenceTracker
        .scoreFromLogs(
          targetCalories: targets.calories,
          logs: dayLogs,
        )
        .clamp(0.0, 1.0)
        .toDouble();

    return NutritionAdherenceSnapshot(
      userId: userId,
      date: day,
      targetCalories: targets.calories,
      loggedCalories: calories,
      targetProtein: targets.proteinG,
      loggedProtein: protein,
      targetCarbs: targets.carbsG,
      loggedCarbs: carbs,
      targetFat: targets.fatG,
      loggedFat: fat,
      expectedMeals: expectedSlots.length,
      loggedMeals: coveredSlots.length,
      mealSlotCoverage: coverage,
      adherenceScore: adherence,
      missingMealSlots: List<MealType>.unmodifiable(missingSlots),
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
