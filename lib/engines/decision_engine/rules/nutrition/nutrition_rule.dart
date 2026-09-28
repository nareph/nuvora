import 'package:gymgenius/domain/entities/nutrition_adherence_snapshot.dart';
import 'package:gymgenius/domain/entities/nutrition_plan.dart';
import 'package:gymgenius/domain/entities/today_workout.dart';
import 'package:gymgenius/domain/entities/workout_decision.dart';
import 'package:gymgenius/domain/enums/fitness_goal.dart';

import '../../models/decision_context.dart';
import '../decision_rule.dart';
import 'nutrition_plan_builder.dart';

/// Decision Engine rule for the nutrition domain.
///
/// Phase 13 exposes the synthesized nutrition state through [DecisionContext].
/// Workout-side mutation remains unchanged for now; nutrition decisions are
/// still owned by the Nutrition Engine and are attached after workout
/// conflict resolution.
class NutritionRule implements DecisionRule {
  final NutritionPlanBuilder _planBuilder;

  const NutritionRule({
    required NutritionPlanBuilder planBuilder,
  }) : _planBuilder = planBuilder;

  @override
  WorkoutDecision evaluate(DecisionContext context) {
    if (context.todayWorkout.isRestDay) {
      return WorkoutDecision.keepPlannedWorkout(confidence: 1.0);
    }
    if (context.healthProfile.goal == FitnessGoal.loseFat) {
      return WorkoutDecision.keepPlannedWorkout(confidence: 0.95);
    }
    return WorkoutDecision.keepPlannedWorkout();
  }

  Future<NutritionAdherenceSnapshot> buildNutritionAdherenceSnapshot({
    required DecisionContext context,
    required TodayWorkout plannedWorkout,
  }) {
    return _planBuilder.buildAdherenceSnapshot(
      context: context,
      plannedWorkout: plannedWorkout,
    );
  }

  NutritionPlan buildNutritionPlan({
    required DecisionContext context,
    required TodayWorkout finalWorkout,
  }) {
    return _planBuilder.build(
      context: context,
      finalWorkout: finalWorkout,
    );
  }

  Future<NutritionPlan> buildAndPersistNutritionPlan({
    required DecisionContext context,
    required TodayWorkout finalWorkout,
  }) {
    return _planBuilder.buildAndPersist(
      context: context,
      finalWorkout: finalWorkout,
    );
  }
}
