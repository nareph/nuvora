import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/domain/entities/daily_checkin.dart';
import 'package:gymgenius/domain/entities/health_platform_snapshot.dart';
import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/entities/nutrition_adherence_snapshot.dart';
import 'package:gymgenius/domain/entities/progress_snapshot.dart';
import 'package:gymgenius/domain/entities/recovery_status.dart';
import 'package:gymgenius/domain/entities/today_workout.dart';
import 'package:gymgenius/domain/entities/training_program.dart';
import 'package:gymgenius/domain/entities/workout_decision.dart';

import 'package:gymgenius/engines/decision_engine/Progression/program_progress_service.dart';
import 'package:gymgenius/engines/decision_engine/builders/health_decision_builder.dart';
import 'package:gymgenius/engines/decision_engine/policies/program_refresh_policy.dart';
import 'package:gymgenius/engines/decision_engine/services/conflict_resolver.dart';
import 'package:gymgenius/engines/decision_engine/rules/nutrition/nutrition_rule.dart';

import 'package:gymgenius/engines/recovery_engine/recovery_engine.dart';
import 'package:gymgenius/engines/workout_engine/planner/split_catalog.dart';

import 'builders/today_workout_builder.dart';
import 'models/daily_plan.dart';
import 'models/decision_context.dart';
import 'models/health_decision.dart';
import 'models/program_progress.dart';
import 'rules/decision_rule.dart';
import 'services/workout_adaptation_service.dart';

/// Central orchestrator of the Decision Engine.
///
/// Responsibilities:
///
/// • Build DecisionContext
/// • Execute every DecisionRule
/// • Resolve conflicts
/// • Adapt today's workout
/// • Attach NutritionPlan
/// • Build HealthDecision
/// • Produce the final DailyPlan
///
/// The DecisionEngine itself contains no domain business logic.
class DecisionEngine {
  final ProgramProgressService _programProgressService;
  final TodayWorkoutBuilder _todayWorkoutBuilder;
  final WorkoutAdaptationService _workoutAdaptationService;
  final ConflictResolver _conflictResolver;
  final NutritionRule _nutritionRule;
  final RecoveryEngine _recoveryEngine;
  final HealthDecisionBuilder _healthDecisionBuilder;

  final List<DecisionRule> _rules;

  const DecisionEngine({
    required ProgramProgressService programProgressService,
    required TodayWorkoutBuilder todayWorkoutBuilder,
    required WorkoutAdaptationService workoutAdaptationService,
    required ConflictResolver conflictResolver,
    required List<DecisionRule> rules,
    required NutritionRule nutritionRule,
    RecoveryEngine recoveryEngine = const RecoveryEngine(),
    HealthDecisionBuilder healthDecisionBuilder = const HealthDecisionBuilder(),
  })  : _programProgressService = programProgressService,
        _todayWorkoutBuilder = todayWorkoutBuilder,
        _workoutAdaptationService = workoutAdaptationService,
        _conflictResolver = conflictResolver,
        _rules = rules,
        _nutritionRule = nutritionRule,
        _recoveryEngine = recoveryEngine,
        _healthDecisionBuilder = healthDecisionBuilder;

  // ============================================================
  // Daily Plan
  // ============================================================

  /// Builds the complete plan for today.
  ///
  /// The synchronous path never performs nutrition repository I/O. Callers
  /// may provide an already-computed [nutritionAdherenceSnapshot] when they
  /// have one available.
  DailyPlan buildDailyPlan(
    TrainingProgram trainingProgram,
    HealthProfile healthProfile, {
    DateTime? now,
    DailyCheckIn? checkIn,
    ProgressSnapshot? progressSnapshot,
    HealthPlatformSnapshot? healthPlatformSnapshot,
    NutritionAdherenceSnapshot? nutritionAdherenceSnapshot,
  }) {
    final currentDate = now ?? DateTime.now();

    final progress = _programProgressService.calculate(
      trainingProgram,
      now: currentDate,
    );

    final splitDisplayName = _findSplitDisplayName(
      trainingProgram,
      currentDate,
    );

    final plannedWorkout = _todayWorkoutBuilder.build(
      program: trainingProgram,
      splitDisplayName: splitDisplayName,
      now: currentDate,
    );

    // No check-in means no recovery computation.
    final RecoveryStatus? recoveryStatus =
        checkIn != null ? _recoveryEngine.compute(checkIn) : null;

    final context = DecisionContext(
      now: currentDate,
      healthProfile: healthProfile,
      trainingProgram: trainingProgram,
      programProgress: progress,
      todayWorkout: plannedWorkout,
      recoveryStatus: recoveryStatus,
      progressSnapshot: progressSnapshot,
      healthPlatformSnapshot: healthPlatformSnapshot,
      nutritionAdherenceSnapshot: nutritionAdherenceSnapshot,
    );

    return _buildDailyPlanFromContext(
      context: context,
      progress: progress,
      plannedWorkout: plannedWorkout,
      healthProfile: healthProfile,
      currentDate: currentDate,
      recoveryStatus: recoveryStatus,
      progressSnapshot: progressSnapshot,
      healthPlatformSnapshot: healthPlatformSnapshot,
    );
  }

  /// Builds the daily plan and persists recovery data only when a real
  /// DailyCheckIn has been supplied.
  ///
  /// Before rules are evaluated, the Decision Engine obtains a compact
  /// nutrition snapshot through the NutritionRule boundary. Raw nutrition
  /// logs never enter DecisionContext.
  Future<DailyPlan> buildDailyPlanAndPersist(
    TrainingProgram trainingProgram,
    HealthProfile healthProfile, {
    DateTime? now,
    DailyCheckIn? checkIn,
    ProgressSnapshot? progressSnapshot,
    HealthPlatformSnapshot? healthPlatformSnapshot,
  }) async {
    final currentDate = now ?? DateTime.now();

    final progress = _programProgressService.calculate(
      trainingProgram,
    );

    final splitDisplayName = _findSplitDisplayName(
      trainingProgram,
      currentDate,
    );

    final plannedWorkout = _todayWorkoutBuilder.build(
      program: trainingProgram,
      splitDisplayName: splitDisplayName,
      now: currentDate,
    );

    RecoveryStatus? recoveryStatus;

    // Recovery persistence happens ONLY after an actual check-in.
    if (checkIn != null) {
      recoveryStatus = await _recoveryEngine.computeAndPersist(
        checkIn,
      );
    }

    final baseContext = DecisionContext(
      now: currentDate,
      healthProfile: healthProfile,
      trainingProgram: trainingProgram,
      programProgress: progress,
      todayWorkout: plannedWorkout,
      recoveryStatus: recoveryStatus,
      progressSnapshot: progressSnapshot,
      healthPlatformSnapshot: healthPlatformSnapshot,
    );

    NutritionAdherenceSnapshot? nutritionAdherenceSnapshot;
    try {
      nutritionAdherenceSnapshot =
          await _nutritionRule.buildNutritionAdherenceSnapshot(
        context: baseContext,
        plannedWorkout: plannedWorkout,
      );
    } catch (e, s) {
      // Nutrition analysis must not make the complete Decision Engine fail.
      // The context remains valid; nutrition-dependent rules can treat a null
      // snapshot as "no nutrition observation available".
      Log.error(
        'DecisionEngine: Nutrition adherence snapshot failed',
        error: e,
        stackTrace: s,
      );
    }

    final context = baseContext.copyWith(
      nutritionAdherenceSnapshot: nutritionAdherenceSnapshot,
    );

    final decisions = _evaluateRules(context);

    final finalDecision = _conflictResolver.resolve(decisions);

    final finalWorkout = _workoutAdaptationService.adapt(
      plannedWorkout: plannedWorkout,
      decision: finalDecision,
      profile: healthProfile,
    );

    final adaptedContext = context.copyWith(
      todayWorkout: finalWorkout,
    );

    final nutritionPlan = await _nutritionRule.buildAndPersistNutritionPlan(
      context: adaptedContext,
      finalWorkout: finalWorkout,
    );

    final programRefresh = ProgramRefreshPolicy.evaluate(
      program: trainingProgram,
      progress: progress,
      snapshot: progressSnapshot,
      now: currentDate,
    );

    final healthDecision = _healthDecisionBuilder.build(
      generatedAt: currentDate,
      finalDecision: finalDecision,
      recoveryStatus: recoveryStatus,
      progressSnapshot: progressSnapshot,
      programRefresh: programRefresh,
    );

    return DailyPlan(
      context: adaptedContext,
      programProgress: progress,
      todayWorkout: finalWorkout,
      finalDecision: finalDecision,
      nutritionPlan: nutritionPlan,
      recoveryStatus: recoveryStatus,
      progressSnapshot: progressSnapshot,
      healthPlatformSnapshot: healthPlatformSnapshot,
      healthDecision: healthDecision,
      programRefresh: programRefresh,
      confidence: finalDecision.confidence.clamp(0.0, 1.0),
      generatedAt: currentDate,
    );
  }

  /// Internal synchronous builder used by [buildDailyPlan].
  DailyPlan _buildDailyPlanFromContext({
    required DecisionContext context,
    required ProgramProgress progress,
    required TodayWorkout plannedWorkout,
    required HealthProfile healthProfile,
    required DateTime currentDate,
    RecoveryStatus? recoveryStatus,
    ProgressSnapshot? progressSnapshot,
    HealthPlatformSnapshot? healthPlatformSnapshot,
  }) {
    final decisions = _evaluateRules(context);

    final finalDecision = _conflictResolver.resolve(decisions);

    final finalWorkout = _workoutAdaptationService.adapt(
      plannedWorkout: plannedWorkout,
      decision: finalDecision,
      profile: healthProfile,
    );

    final adaptedContext = context.copyWith(
      todayWorkout: finalWorkout,
    );

    final nutritionPlan = _nutritionRule.buildNutritionPlan(
      context: adaptedContext,
      finalWorkout: finalWorkout,
    );

    final programRefresh = ProgramRefreshPolicy.evaluate(
      program: context.trainingProgram,
      progress: progress,
      snapshot: progressSnapshot,
      now: currentDate,
    );

    final healthDecision = _healthDecisionBuilder.build(
      generatedAt: currentDate,
      finalDecision: finalDecision,
      recoveryStatus: recoveryStatus,
      progressSnapshot: progressSnapshot,
      programRefresh: programRefresh,
    );

    return DailyPlan(
      context: adaptedContext,
      programProgress: progress,
      todayWorkout: finalWorkout,
      finalDecision: finalDecision,
      nutritionPlan: nutritionPlan,
      recoveryStatus: recoveryStatus,
      progressSnapshot: progressSnapshot,
      healthPlatformSnapshot: healthPlatformSnapshot,
      healthDecision: healthDecision,
      programRefresh: programRefresh,
      confidence: finalDecision.confidence.clamp(0.0, 1.0),
      generatedAt: currentDate,
    );
  }

  /// Evaluates all registered rules against the current context.
  List<WorkoutDecision> _evaluateRules(
    DecisionContext context,
  ) {
    final decisions = <WorkoutDecision>[];

    for (final rule in _rules) {
      decisions.add(
        rule.evaluate(context),
      );
    }

    return decisions;
  }

  // ============================================================
  // Convenience methods
  // ============================================================

  ProgramProgress getProgramProgress(
    TrainingProgram program,
  ) {
    return _programProgressService.calculate(
      program,
    );
  }

  TodayWorkout getTodayWorkout(
    TrainingProgram trainingProgram,
    HealthProfile healthProfile, {
    DateTime? now,
  }) {
    return buildDailyPlan(
      trainingProgram,
      healthProfile,
      now: now,
    ).todayWorkout;
  }

  /// Fallback health recommendation when no DailyPlan exists.
  HealthDecision getDefaultDecision({
    DateTime? now,
  }) {
    return _healthDecisionBuilder.build(
      generatedAt: now ?? DateTime.now(),
      finalDecision: WorkoutDecision.keepPlannedWorkout(
        confidence: 0.5,
      ),
      recoveryStatus: null,
      progressSnapshot: null,
    );
  }

  // ============================================================
  // Helpers
  // ============================================================

  String _dayKey(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'monday';

      case DateTime.tuesday:
        return 'tuesday';

      case DateTime.wednesday:
        return 'wednesday';

      case DateTime.thursday:
        return 'thursday';

      case DateTime.friday:
        return 'friday';

      case DateTime.saturday:
        return 'saturday';

      case DateTime.sunday:
        return 'sunday';

      default:
        throw StateError(
          'Invalid weekday: ${date.weekday}',
        );
    }
  }

  /// Determines the display name of today's split.
  ///
  /// The program remains the source of truth for the generated weekly
  /// structure. The catalog is only used here for the stable display template.
  String _findSplitDisplayName(
    TrainingProgram program,
    DateTime date,
  ) {
    final dayKey = _dayKey(date);

    final workoutDays = program.weeklySchedule.entries
        .where(
          (entry) => entry.value.isNotEmpty,
        )
        .map(
          (entry) => entry.key,
        )
        .toList();

    if (workoutDays.isEmpty) {
      return 'Workout';
    }

    final index = workoutDays.indexOf(dayKey);

    if (index == -1) {
      return 'Workout';
    }

    final template = SplitCatalog.templateForDays(
      workoutDays.length,
    );

    if (index >= template.length) {
      return 'Workout';
    }

    return template[index].displayName;
  }
}
