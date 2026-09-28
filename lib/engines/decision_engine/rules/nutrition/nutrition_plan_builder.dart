import 'package:gymgenius/domain/entities/nutrition_adherence_snapshot.dart';
import 'package:gymgenius/domain/entities/nutrition_plan.dart';
import 'package:gymgenius/domain/entities/today_workout.dart';
import 'package:gymgenius/engines/decision_engine/models/decision_context.dart';
import 'package:gymgenius/engines/nutrition_engine/nutrition_engine.dart';

/// Builds a [NutritionPlan] from Decision Engine context and the final workout.
///
/// Bridges Workout adaptations (rest day, recovery session, deload) into
/// nutrition targets without duplicating Nutrition Engine calculations.
class NutritionPlanBuilder {
  final NutritionEngine _nutritionEngine;

  const NutritionPlanBuilder({
    required NutritionEngine nutritionEngine,
  }) : _nutritionEngine = nutritionEngine;

  NutritionPlan build({
    required DecisionContext context,
    required TodayWorkout finalWorkout,
  }) {
    final isTrainingDay = _isTrainingDay(finalWorkout);
    final trainingLoad = _trainingLoad(
      finalWorkout: finalWorkout,
      isTrainingDay: isTrainingDay,
    );

    final basePlan = _nutritionEngine.computeDailyPlanSync(
      profile: context.healthProfile,
      isTrainingDay: isTrainingDay,
      date: context.now,
      trainingLoad: trainingLoad,
    );

    return _addCrossDomainReasons(
      basePlan: basePlan,
      context: context,
      finalWorkout: finalWorkout,
      isTrainingDay: isTrainingDay,
      trainingLoad: trainingLoad,
    );
  }

  /// Builds and persists the final nutrition plan.
  ///
  /// Unlike the synchronous path, this method can load recent nutrition logs
  /// through [NutritionEngine.computeDailyPlan], allowing the MealPlanner to
  /// actively reduce repetition over the previous seven days.
  Future<NutritionPlan> buildAndPersist({
    required DecisionContext context,
    required TodayWorkout finalWorkout,
  }) async {
    final isTrainingDay = _isTrainingDay(finalWorkout);
    final trainingLoad = _trainingLoad(
      finalWorkout: finalWorkout,
      isTrainingDay: isTrainingDay,
    );

    final basePlan = await _nutritionEngine.computeDailyPlan(
      profile: context.healthProfile,
      isTrainingDay: isTrainingDay,
      date: context.now,
      trainingLoad: trainingLoad,
      persist: false,
    );

    final plan = _addCrossDomainReasons(
      basePlan: basePlan,
      context: context,
      finalWorkout: finalWorkout,
      isTrainingDay: isTrainingDay,
      trainingLoad: trainingLoad,
    );

    await _nutritionEngine.persistPlan(
      plan: plan,
      profile: context.healthProfile,
    );

    return plan;
  }

  /// Builds the nutrition state that is exposed to the Decision Engine.
  ///
  /// This intentionally uses the planned workout that exists before decision
  /// rules are evaluated. That gives rules a deterministic snapshot of the
  /// user's observed nutrition state at decision time without creating a
  /// circular dependency on the final adapted workout.
  Future<NutritionAdherenceSnapshot> buildAdherenceSnapshot({
    required DecisionContext context,
    required TodayWorkout plannedWorkout,
  }) async {
    final isTrainingDay = _isTrainingDay(plannedWorkout);
    final trainingLoad = _trainingLoad(
      finalWorkout: plannedWorkout,
      isTrainingDay: isTrainingDay,
    );

    final plan = await _nutritionEngine.computeDailyPlan(
      profile: context.healthProfile,
      isTrainingDay: isTrainingDay,
      date: context.now,
      trainingLoad: trainingLoad,
      persist: false,
    );

    return _nutritionEngine.buildAdherenceSnapshotForDay(
      plan: plan,
    );
  }

  bool _isTrainingDay(TodayWorkout finalWorkout) {
    return finalWorkout.hasExercises &&
        !finalWorkout.isRecoverySession &&
        !finalWorkout.isRestDay;
  }

  /// 0 = rest/recovery calories, 1 = full training bonus.
  /// Daily volume cuts (deload, reduceVolume) scale the bonus in between.
  double _trainingLoad({
    required TodayWorkout finalWorkout,
    required bool isTrainingDay,
  }) {
    if (!isTrainingDay) return 0;
    return finalWorkout.volumeMultiplier.clamp(0.0, 1.0);
  }

  NutritionPlan _addCrossDomainReasons({
    required NutritionPlan basePlan,
    required DecisionContext context,
    required TodayWorkout finalWorkout,
    required bool isTrainingDay,
    required double trainingLoad,
  }) {
    final extraReasons = <String>[];

    if (finalWorkout.isRestDay) {
      extraReasons.add(
        'Rest day: calories adjusted for recovery without training bonus.',
      );
    } else if (finalWorkout.isRecoverySession) {
      extraReasons.add(
        'Recovery session: nutrition plan uses rest-day energy targets.',
      );
    } else if (isTrainingDay && trainingLoad < 0.99) {
      extraReasons.add(
        'Workout volume is ${(trainingLoad * 100).round()}% of a full session — '
        'calories and carbs scaled to match.',
      );
    }

    if (context.programProgress.deloadPlan.isDeload) {
      extraReasons.add(
        'Deload week: maintain protein and support recovery with adequate carbs.',
      );
    }

    if (extraReasons.isEmpty) return basePlan;

    return NutritionPlan(
      userId: basePlan.userId,
      date: basePlan.date,
      targets: basePlan.targets,
      maintenanceCalories: basePlan.maintenanceCalories,
      status: basePlan.status,
      meals: basePlan.meals,
      country: basePlan.country,
      isTrainingDay: basePlan.isTrainingDay,
      reasons: [...basePlan.reasons, ...extraReasons],
      generatedBy: basePlan.generatedBy,
    );
  }
}
