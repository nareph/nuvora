import 'package:gymgenius/domain/enums/decision_reason.dart';
import 'package:gymgenius/domain/enums/health_caution_level.dart';
import 'package:gymgenius/domain/enums/nutrition_status.dart';
import 'package:gymgenius/domain/enums/workout_adjustment.dart';
import 'package:gymgenius/engines/ai_coach/models/coach_context.dart';
import 'package:gymgenius/engines/decision_engine/models/daily_plan.dart';

import '../../../domain/enums/exports.dart';

/// Builds a compact [CoachContext] from a [DailyPlan].
///
/// The builder only consumes deterministic data already produced by the
/// Decision Engine. It never accesses raw repositories, Hive, or nutrition
/// logs directly.
class CoachContextBuilder {
  const CoachContextBuilder();

  CoachContext build(DailyPlan plan) {
    final profile = plan.context.healthProfile;
    final decision = plan.finalDecision;
    final recovery = plan.recoveryStatus;
    final nutrition = plan.nutritionPlan;
    final nutritionAdherence = plan.context.nutritionAdherenceSnapshot;
    final progress = plan.progressSnapshot;
    final health = plan.healthDecision;
    final hp = plan.healthPlatformSnapshot;

    return CoachContext(
      userId: profile.userId,
      now: plan.generatedAt,

      // ----------------------------------------------------------------------
      // Profile
      // ----------------------------------------------------------------------

      goal: profile.goal.value,
      experience: profile.experience.value,

      // ----------------------------------------------------------------------
      // Workout decision
      // ----------------------------------------------------------------------

      isRestDay: plan.isRestDay,
      isAdapted: plan.isAdapted,
      workoutAdjustment: decision.adjustment.value,
      decisionReasons:
          decision.reasons.map((r) => r.displayName).toList(growable: false),
      plannedExerciseCount: plan.todayWorkout.finalExerciseCount,

      // ----------------------------------------------------------------------
      // Recovery
      // ----------------------------------------------------------------------

      readinessScore: recovery?.readinessScore,
      recoveryScore: recovery?.recoveryScore,
      volumeMultiplier: recovery?.volumeMultiplier ?? decision.volumeMultiplier,

      // ----------------------------------------------------------------------
      // Nutrition plan
      // ----------------------------------------------------------------------

      nutritionCalories: nutrition?.targets.calories,
      nutritionProteinG: nutrition?.targets.proteinG,
      nutritionStatus: nutrition?.status.value,

      // ----------------------------------------------------------------------
      // Nutrition adherence
      //
      // Comes exclusively from the deterministic
      // NutritionAdherenceSnapshot stored in DecisionContext.
      // No raw NutritionLog is exposed to the AI Coach.
      // ----------------------------------------------------------------------

      nutritionLoggedCalories: nutritionAdherence?.loggedCalories,
      nutritionLoggedProteinG: nutritionAdherence?.loggedProtein,
      nutritionLoggedCarbsG: nutritionAdherence?.loggedCarbs,
      nutritionLoggedFatG: nutritionAdherence?.loggedFat,
      nutritionExpectedMeals: nutritionAdherence?.expectedMeals,
      nutritionLoggedMeals: nutritionAdherence?.loggedMeals,
      nutritionMealSlotCoverage: nutritionAdherence?.mealSlotCoverage,
      nutritionAdherenceScore: nutritionAdherence?.adherenceScore,
      nutritionMissingMealSlots: nutritionAdherence == null
          ? const []
          : nutritionAdherence.missingMealSlots
              .map((slot) => slot.value)
              .toList(growable: false),

      // ----------------------------------------------------------------------
      // Progress
      // ----------------------------------------------------------------------

      consistencyScore: progress?.consistency?.consistencyScore,
      weightPlateau: progress?.weightPlateauDetected ?? false,
      strengthPlateau: progress?.strengthPlateauDetected ?? false,
      progressReasons: progress?.reasons ?? const [],

      // ----------------------------------------------------------------------
      // Health decision
      // ----------------------------------------------------------------------

      healthPrimaryAction: health?.primaryAction,
      healthReason: health?.reason,

      // ----------------------------------------------------------------------
      // Decision confidence
      // ----------------------------------------------------------------------

      decisionConfidence: plan.confidence,

      // ----------------------------------------------------------------------
      // Health Platform
      //
      // Safe synthesized labels only. No raw BP/glucose values.
      // ----------------------------------------------------------------------

      hydrationPercent: hp?.hydrationPercent,
      habitsCompletionPercent: hp?.habitsCompletionPercent,
      habitsStreakSummary: hp == null
          ? null
          : (hp.longestCurrentStreak > 0
              ? 'longest_streak_${hp.longestCurrentStreak}'
              : 'no_streak'),
      wellnessTrend: hp?.wellnessTrendLabel,
      hasBpCaution: hp?.hasBpCaution ?? false,
      hasGlucoseCaution: hp?.hasGlucoseCaution ?? false,
      healthPlatformCaution: hp?.overallCaution.value,
    );
  }
}
