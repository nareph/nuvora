import 'package:gymgenius/domain/enums/meal_type.dart';

/// Deterministic summary of observed nutrition for one planned day.
///
/// Higher-level engines consume this synthesized state instead of accessing
/// raw nutrition logs or UI-specific logging details.
class NutritionAdherenceSnapshot {
  final String userId;
  final DateTime date;

  final int targetCalories;
  final int loggedCalories;

  final int targetProtein;
  final int loggedProtein;

  final int targetCarbs;
  final int loggedCarbs;

  final int targetFat;
  final int loggedFat;

  /// Number of distinct meal slots expected by the current plan.
  final int expectedMeals;

  /// Number of distinct expected meal slots with at least one log.
  /// Multiple logs in the same slot count as one covered meal.
  final int loggedMeals;

  /// Fraction of expected slots covered by at least one log, in [0, 1].
  final double mealSlotCoverage;

  /// Deterministic calorie-adherence score produced by the nutrition tracker.
  final double adherenceScore;

  /// Expected slots that have not yet been logged.
  final List<MealType> missingMealSlots;

  const NutritionAdherenceSnapshot({
    required this.userId,
    required this.date,
    required this.targetCalories,
    required this.loggedCalories,
    required this.targetProtein,
    required this.loggedProtein,
    required this.targetCarbs,
    required this.loggedCarbs,
    required this.targetFat,
    required this.loggedFat,
    required this.expectedMeals,
    required this.loggedMeals,
    required this.mealSlotCoverage,
    required this.adherenceScore,
    this.missingMealSlots = const [],
  })  : assert(userId != ''),
        assert(targetCalories >= 0),
        assert(loggedCalories >= 0),
        assert(targetProtein >= 0),
        assert(loggedProtein >= 0),
        assert(targetCarbs >= 0),
        assert(loggedCarbs >= 0),
        assert(targetFat >= 0),
        assert(loggedFat >= 0),
        assert(expectedMeals >= 0),
        assert(loggedMeals >= 0),
        assert(mealSlotCoverage >= 0 && mealSlotCoverage <= 1),
        assert(adherenceScore >= 0 && adherenceScore <= 1);

  double _coverage(int logged, int target) {
    if (target <= 0) return 0;
    return (logged / target).clamp(0.0, 1.0).toDouble();
  }

  double get calorieCoverage => _coverage(loggedCalories, targetCalories);

  double get proteinCoverage => _coverage(loggedProtein, targetProtein);

  double get carbsCoverage => _coverage(loggedCarbs, targetCarbs);

  double get fatCoverage => _coverage(loggedFat, targetFat);

  int get remainingCalories =>
      (targetCalories - loggedCalories).clamp(0, targetCalories);

  int get remainingProtein =>
      (targetProtein - loggedProtein).clamp(0, targetProtein);

  int get remainingCarbs =>
      (targetCarbs - loggedCarbs).clamp(0, targetCarbs);

  int get remainingFat =>
      (targetFat - loggedFat).clamp(0, targetFat);

  int get missingMeals => missingMealSlots.length;

  bool get hasObservedIntake => loggedMeals > 0;

  NutritionAdherenceSnapshot copyWith({
    String? userId,
    DateTime? date,
    int? targetCalories,
    int? loggedCalories,
    int? targetProtein,
    int? loggedProtein,
    int? targetCarbs,
    int? loggedCarbs,
    int? targetFat,
    int? loggedFat,
    int? expectedMeals,
    int? loggedMeals,
    double? mealSlotCoverage,
    double? adherenceScore,
    List<MealType>? missingMealSlots,
  }) {
    return NutritionAdherenceSnapshot(
      userId: userId ?? this.userId,
      date: date ?? this.date,
      targetCalories: targetCalories ?? this.targetCalories,
      loggedCalories: loggedCalories ?? this.loggedCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      loggedProtein: loggedProtein ?? this.loggedProtein,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      loggedCarbs: loggedCarbs ?? this.loggedCarbs,
      targetFat: targetFat ?? this.targetFat,
      loggedFat: loggedFat ?? this.loggedFat,
      expectedMeals: expectedMeals ?? this.expectedMeals,
      loggedMeals: loggedMeals ?? this.loggedMeals,
      mealSlotCoverage: mealSlotCoverage ?? this.mealSlotCoverage,
      adherenceScore: adherenceScore ?? this.adherenceScore,
      missingMealSlots: missingMealSlots ?? this.missingMealSlots,
    );
  }
}
