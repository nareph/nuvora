import 'package:gymgenius/domain/enums/workout_adjustment.dart';

/// Compact, LLM-safe snapshot of today's decision context.
///
/// Built from [DailyPlan] — never from raw Hive access in the LLM layer.
///
/// The context contains only deterministic, already-synthesized information.
/// The AI Coach explains and communicates this state; it does not make
/// workout, nutrition, recovery, or health decisions.
class CoachContext {
  final String userId;
  final DateTime now;

  final String? goal;
  final String? experience;

  final bool isRestDay;
  final bool isAdapted;
  final String workoutAdjustment;
  final List<String> decisionReasons;
  final int plannedExerciseCount;

  final int? readinessScore;
  final int? recoveryScore;
  final double? volumeMultiplier;

  // --------------------------------------------------------------------------
  // Nutrition plan
  // --------------------------------------------------------------------------

  /// Deterministic nutrition target for today's plan.
  final int? nutritionCalories;

  /// Deterministic daily protein target.
  final int? nutritionProteinG;

  /// Current deterministic nutrition status.
  final String? nutritionStatus;

  // --------------------------------------------------------------------------
  // Nutrition adherence
  // --------------------------------------------------------------------------

  /// Calories actually logged for the planned day.
  ///
  /// This comes from [NutritionAdherenceSnapshot], never from raw logs.
  final int? nutritionLoggedCalories;

  /// Protein actually logged for the planned day.
  final int? nutritionLoggedProteinG;

  /// Carbohydrates actually logged for the planned day.
  final int? nutritionLoggedCarbsG;

  /// Fat actually logged for the planned day.
  final int? nutritionLoggedFatG;

  /// Number of meal slots expected by today's nutrition plan.
  final int? nutritionExpectedMeals;

  /// Number of expected meal slots covered by at least one log.
  final int? nutritionLoggedMeals;

  /// Fraction of expected meal slots covered, in [0, 1].
  final double? nutritionMealSlotCoverage;

  /// Deterministic calorie-adherence score, in [0, 1].
  final double? nutritionAdherenceScore;

  /// Human-readable identifiers/labels of expected meal slots that are
  /// not yet covered.
  ///
  /// These are safe labels only; no raw NutritionLog data is exposed.
  final List<String> nutritionMissingMealSlots;

  // --------------------------------------------------------------------------
  // Progress
  // --------------------------------------------------------------------------

  final int? consistencyScore;
  final bool weightPlateau;
  final bool strengthPlateau;
  final List<String> progressReasons;

  // --------------------------------------------------------------------------
  // Health decision
  // --------------------------------------------------------------------------

  final String? healthPrimaryAction;
  final String? healthReason;

  /// Confidence of the deterministic Decision Engine result.
  final double decisionConfidence;

  // --------------------------------------------------------------------------
  // Health Platform
  //
  // Safe labels only — no raw blood pressure or glucose measurements.
  // --------------------------------------------------------------------------

  final int? hydrationPercent;
  final int? habitsCompletionPercent;
  final String? habitsStreakSummary;
  final String? wellnessTrend;
  final bool hasBpCaution;
  final bool hasGlucoseCaution;
  final String? healthPlatformCaution;

  const CoachContext({
    required this.userId,
    required this.now,
    this.goal,
    this.experience,
    required this.isRestDay,
    required this.isAdapted,
    required this.workoutAdjustment,
    required this.decisionReasons,
    required this.plannedExerciseCount,
    this.readinessScore,
    this.recoveryScore,
    this.volumeMultiplier,

    // Nutrition plan.
    this.nutritionCalories,
    this.nutritionProteinG,
    this.nutritionStatus,

    // Nutrition adherence.
    this.nutritionLoggedCalories,
    this.nutritionLoggedProteinG,
    this.nutritionLoggedCarbsG,
    this.nutritionLoggedFatG,
    this.nutritionExpectedMeals,
    this.nutritionLoggedMeals,
    this.nutritionMealSlotCoverage,
    this.nutritionAdherenceScore,
    this.nutritionMissingMealSlots = const [],

    // Progress.
    this.consistencyScore,
    this.weightPlateau = false,
    this.strengthPlateau = false,
    this.progressReasons = const [],

    // Health decision.
    this.healthPrimaryAction,
    this.healthReason,
    required this.decisionConfidence,

    // Health Platform.
    this.hydrationPercent,
    this.habitsCompletionPercent,
    this.habitsStreakSummary,
    this.wellnessTrend,
    this.hasBpCaution = false,
    this.hasGlucoseCaution = false,
    this.healthPlatformCaution,
  });

  /// Whether today's workout volume/intensity was reduced by the
  /// deterministic Decision Engine.
  bool get volumeWasReduced =>
      workoutAdjustment == WorkoutAdjustment.reduceVolume.value ||
      workoutAdjustment == WorkoutAdjustment.deload.value ||
      workoutAdjustment == WorkoutAdjustment.reduceIntensity.value ||
      (volumeMultiplier != null && volumeMultiplier! < 1.0);

  /// Rest, skip, recovery session, or reduced volume — coach must not push
  /// harder or recommend additional training.
  bool get isProtectiveDay =>
      isRestDay ||
      workoutAdjustment == WorkoutAdjustment.restDay.value ||
      workoutAdjustment == WorkoutAdjustment.recoverySession.value ||
      workoutAdjustment == WorkoutAdjustment.skipWorkout.value ||
      volumeWasReduced;

  /// Whether a nutrition adherence snapshot contains observed intake data.
  bool get hasNutritionAdherence =>
      nutritionExpectedMeals != null ||
      nutritionLoggedMeals != null ||
      nutritionAdherenceScore != null;

  /// Whether at least one planned nutrition meal slot has been logged.
  bool get hasLoggedNutrition => (nutritionLoggedMeals ?? 0) > 0;

  /// Whether all expected nutrition meal slots have been covered.
  bool get allNutritionMealsLogged {
    final expected = nutritionExpectedMeals;
    final logged = nutritionLoggedMeals;

    if (expected == null || logged == null) {
      return false;
    }

    return expected > 0 && logged >= expected;
  }

  Map<String, dynamic> toPromptMap() {
    return {
      'userId': userId,
      'date': now.toIso8601String(),

      // Profile.
      'goal': goal,
      'experience': experience,

      // Workout decision.
      'isRestDay': isRestDay,
      'isAdapted': isAdapted,
      'workoutAdjustment': workoutAdjustment,
      'decisionReasons': decisionReasons,
      'plannedExerciseCount': plannedExerciseCount,

      // Recovery.
      'readinessScore': readinessScore,
      'recoveryScore': recoveryScore,
      'volumeMultiplier': volumeMultiplier,

      // Nutrition plan.
      'nutritionCalories': nutritionCalories,
      'nutritionProteinG': nutritionProteinG,
      'nutritionStatus': nutritionStatus,

      // Nutrition adherence.
      'nutritionLoggedCalories': nutritionLoggedCalories,
      'nutritionLoggedProteinG': nutritionLoggedProteinG,
      'nutritionLoggedCarbsG': nutritionLoggedCarbsG,
      'nutritionLoggedFatG': nutritionLoggedFatG,
      'nutritionExpectedMeals': nutritionExpectedMeals,
      'nutritionLoggedMeals': nutritionLoggedMeals,
      'nutritionMealSlotCoverage': nutritionMealSlotCoverage,
      'nutritionAdherenceScore': nutritionAdherenceScore,
      'nutritionMissingMealSlots': nutritionMissingMealSlots,

      // Progress.
      'consistencyScore': consistencyScore,
      'weightPlateau': weightPlateau,
      'strengthPlateau': strengthPlateau,
      'progressReasons': progressReasons,

      // Health decision.
      'healthPrimaryAction': healthPrimaryAction,
      'healthReason': healthReason,

      // Decision confidence.
      'decisionConfidence': decisionConfidence,

      // Health Platform.
      'hydrationPercent': hydrationPercent,
      'habitsCompletionPercent': habitsCompletionPercent,
      'habitsStreakSummary': habitsStreakSummary,
      'wellnessTrend': wellnessTrend,
      'hasBpCaution': hasBpCaution,
      'hasGlucoseCaution': hasGlucoseCaution,
      'healthPlatformCaution': healthPlatformCaution,
    };
  }
}
