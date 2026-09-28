import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/entities/meal.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/entities/nutrition_adherence_snapshot.dart';
import 'package:gymgenius/domain/entities/nutrition_plan.dart';
import 'package:gymgenius/domain/entities/nutrition_profile.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/enums/nutrition_status.dart';
import 'package:gymgenius/domain/repositories/nutrition_repository.dart';
import 'package:gymgenius/engines/nutrition_engine/calculators/calorie_estimator.dart';
import 'package:gymgenius/engines/nutrition_engine/calculators/macro_calculator.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/food_knowledge_base.dart';
import 'package:gymgenius/engines/nutrition_engine/planners/meal_planner.dart';
import 'package:gymgenius/engines/nutrition_engine/trackers/adherence_tracker.dart';
import 'package:gymgenius/engines/nutrition_engine/analyzers/nutrition_adherence_analyzer.dart';

/// Public facade for the Nutrition Engine.
///
/// Deterministic, offline-first. AI must never replace these calculations.
class NutritionEngine {
  final CalorieEstimator _calorieEstimator;
  final MacroCalculator _macroCalculator;
  final MealPlanner _mealPlanner;
  final FoodKnowledgeBase _foodKnowledgeBase;
  final AdherenceTracker _adherenceTracker;
  final NutritionAdherenceAnalyzer _adherenceAnalyzer;
  final NutritionRepository? _nutritionRepository;

  NutritionEngine({
    CalorieEstimator? calorieEstimator,
    MacroCalculator? macroCalculator,
    MealPlanner? mealPlanner,
    FoodKnowledgeBase? foodKnowledgeBase,
    AdherenceTracker? adherenceTracker,
    NutritionAdherenceAnalyzer? adherenceAnalyzer,
    NutritionRepository? nutritionRepository,
  })  : _calorieEstimator = calorieEstimator ?? const CalorieEstimator(),
        _macroCalculator = macroCalculator ?? const MacroCalculator(),
        _foodKnowledgeBase = foodKnowledgeBase ?? const FoodKnowledgeBase(),
        _mealPlanner = mealPlanner ??
            MealPlanner(
              foodKnowledgeBase: foodKnowledgeBase ?? const FoodKnowledgeBase(),
            ),
        _adherenceTracker = adherenceTracker ?? const AdherenceTracker(),
        _adherenceAnalyzer =
            adherenceAnalyzer ?? const NutritionAdherenceAnalyzer(),
        _nutritionRepository = nutritionRepository;

  /// Computes today's structured nutrition plan.
  ///
  /// This async path can use the persisted nutrition history to improve meal
  /// rotation. The history window intentionally excludes [planDate] itself;
  /// today's logs belong to observed intake, not to the initial plan seed.
  Future<NutritionPlan> computeDailyPlan({
    required HealthProfile profile,
    required bool isTrainingDay,
    DateTime? date,
    bool persist = true,
    double trainingLoad = 1.0,
  }) async {
    final planDate = date ?? DateTime.now();
    final day = DateTime(planDate.year, planDate.month, planDate.day);

    final recentLogs = await _loadRecentLogsForPlanning(
      userId: profile.userId,
      planningDate: day,
    );

    final plan = computeDailyPlanSync(
      profile: profile,
      isTrainingDay: isTrainingDay,
      date: day,
      trainingLoad: trainingLoad,
      recentLogs: recentLogs,
    );

    if (persist && _nutritionRepository != null) {
      final adherence = await _adherenceForDay(
        profile.userId,
        day,
        plan.targets.calories,
      );
      await _nutritionRepository!.savePlan(plan);
      await _nutritionRepository!.saveNutritionProfile(
        NutritionProfile(
          userId: profile.userId,
          date: day,
          targets: plan.targets,
          country: plan.country,
          preferredFoods: profile.lifestyle.foodPreferences,
          restrictedFoods: profile.lifestyle.foodRestrictions,
          adherenceScore: adherence,
        ),
      );
      Log.debug('NutritionEngine: final plan persisted for ${profile.userId}');
    }

    return plan;
  }

  /// Replaces one unlogged suggested meal while preserving the rest of the day.
  ///
  /// The MealPlanner remains the single source of truth for candidate
  /// selection. This method checks today's logs, loads recent history, delegates
  /// replacement, rebuilds the plan, and persists the updated plan.
  Future<NutritionPlan> replaceSuggestedMeal({
    required NutritionPlan plan,
    required HealthProfile profile,
    required Meal meal,
  }) async {
    if (_nutritionRepository != null) {
      final todaysLogs = await _nutritionRepository!.getNutritionLogsForDay(
        profile.userId,
        plan.date,
      );
      if (todaysLogs.any((log) => log.planMealId == meal.id)) {
        throw StateError(
          'Cannot change a suggested meal that has already been logged.',
        );
      }
    }

    final recentLogs = await _loadRecentLogsForPlanning(
      userId: profile.userId,
      planningDate: plan.date,
    );

    final replacedMeal = _mealPlanner.replaceMeal(
      profile: profile,
      targets: plan.targets,
      isTrainingDay: plan.isTrainingDay,
      planningDate: plan.date,
      currentMeal: meal,
      currentMeals: plan.meals,
      recentLogs: recentLogs,
    );

    final meals = [
      for (final candidate in plan.meals)
        candidate.id == meal.id ? replacedMeal : candidate,
    ];

    if (meals.length != plan.meals.length ||
        !meals.any((candidate) => candidate.id == replacedMeal.id)) {
      throw StateError('Suggested meal is not part of the current plan.');
    }

    final updatedPlan = NutritionPlan(
      userId: plan.userId,
      date: plan.date,
      targets: plan.targets,
      maintenanceCalories: plan.maintenanceCalories,
      status: plan.status,
      meals: meals,
      country: plan.country,
      isTrainingDay: plan.isTrainingDay,
      reasons: [
        ...plan.reasons,
        'Meal changed: ${replacedMeal.type.displayName} → ${replacedMeal.name}.',
      ],
      generatedBy: plan.generatedBy,
    );

    await persistPlan(
      plan: updatedPlan,
      profile: profile,
    );

    return updatedPlan;
  }

  /// Builds a nutrition snapshot from already loaded daily logs.
  ///
  /// The analyzer is deterministic and does not perform persistence or UI
  /// work, making the resulting snapshot suitable for higher-level engines.
  NutritionAdherenceSnapshot buildAdherenceSnapshot({
    required NutritionPlan plan,
    required Iterable<NutritionLog> logs,
  }) {
    return _adherenceAnalyzer.analyze(
      userId: plan.userId,
      date: plan.date,
      targets: plan.targets,
      plannedMeals: plan.meals,
      logs: logs,
    );
  }

  /// Loads today's logs and builds the corresponding nutrition snapshot.
  Future<NutritionAdherenceSnapshot> buildAdherenceSnapshotForDay({
    required NutritionPlan plan,
  }) async {
    final repo = _nutritionRepository;
    final logs = repo == null
        ? const <NutritionLog>[]
        : await repo.getNutritionLogsForDay(plan.userId, plan.date);

    return buildAdherenceSnapshot(
      plan: plan,
      logs: logs,
    );
  }

  /// Persists a previously computed plan and its matching profile snapshot.
  ///
  /// This is used when the Decision Engine enriches the base nutrition plan
  /// with cross-domain reasons (rest day, deload, recovery session) and the
  /// final version must be stored, not the intermediate one.
  Future<void> persistPlan({
    required NutritionPlan plan,
    required HealthProfile profile,
  }) async {
    if (_nutritionRepository == null) return;

    final adherence = await _adherenceForDay(
      profile.userId,
      plan.date,
      plan.targets.calories,
    );
    await _nutritionRepository!.savePlan(plan);
    await _nutritionRepository!.saveNutritionProfile(
      NutritionProfile(
        userId: profile.userId,
        date: plan.date,
        targets: plan.targets,
        country: plan.country,
        preferredFoods: profile.lifestyle.foodPreferences,
        restrictedFoods: profile.lifestyle.foodRestrictions,
        adherenceScore: adherence,
      ),
    );
    Log.debug('NutritionEngine: final plan persisted for ${profile.userId}');
  }

  /// Persists a nutrition log and refreshes the day's adherence score.
  Future<void> logMeal({
    required NutritionLog log,
    required NutritionPlan plan,
    required HealthProfile profile,
  }) async {
    if (_nutritionRepository == null) return;

    await _nutritionRepository!.saveNutritionLog(log);
    final logs = await _nutritionRepository!.getNutritionLogsForDay(
      profile.userId,
      plan.date,
    );
    final adherence = _adherenceTracker.scoreFromLogs(
      targetCalories: plan.targets.calories,
      logs: logs,
    );
    await _nutritionRepository!.saveNutritionProfile(
      NutritionProfile(
        userId: profile.userId,
        date: plan.date,
        targets: plan.targets,
        country: plan.country,
        preferredFoods: profile.lifestyle.foodPreferences,
        restrictedFoods: profile.lifestyle.foodRestrictions,
        adherenceScore: adherence,
      ),
    );
  }

  Future<void> deleteMealLog({
    required String logId,
    required NutritionPlan plan,
    required HealthProfile profile,
  }) async {
    if (_nutritionRepository == null) return;

    await _nutritionRepository!.deleteNutritionLog(logId);
    final logs = await _nutritionRepository!.getNutritionLogsForDay(
      profile.userId,
      plan.date,
    );
    final adherence = logs.isEmpty
        ? 0.0
        : _adherenceTracker.scoreFromLogs(
            targetCalories: plan.targets.calories,
            logs: logs,
          );
    await _nutritionRepository!.saveNutritionProfile(
      NutritionProfile(
        userId: profile.userId,
        date: plan.date,
        targets: plan.targets,
        country: plan.country,
        preferredFoods: profile.lifestyle.foodPreferences,
        restrictedFoods: profile.lifestyle.foodRestrictions,
        adherenceScore: adherence,
      ),
    );
  }

  Future<double> _adherenceForDay(
    String userId,
    DateTime day,
    int targetCalories,
  ) async {
    final repo = _nutritionRepository;
    if (repo == null) return 0;
    final logs = await repo.getNutritionLogsForDay(userId, day);
    if (logs.isEmpty) return 0;
    return _adherenceTracker.scoreFromLogs(
      targetCalories: targetCalories,
      logs: logs,
    );
  }

  /// Synchronous compute helper for the Decision Engine (no I/O).
  ///
  /// [recentLogs] is optional so callers that already have history can still
  /// provide it without making this method perform repository I/O.
  NutritionPlan computeDailyPlanSync({
    required HealthProfile profile,
    required bool isTrainingDay,
    DateTime? date,
    double trainingLoad = 1.0,
    Iterable<NutritionLog> recentLogs = const <NutritionLog>[],
  }) {
    final planDate = date ?? DateTime.now();
    final day = DateTime(planDate.year, planDate.month, planDate.day);

    final calorieEstimate = _calorieEstimator.estimate(
      profile: profile,
      isTrainingDay: isTrainingDay,
      trainingLoad: trainingLoad,
    );

    final macros = _macroCalculator.calculate(
      profile: profile,
      targetCalories: calorieEstimate.targetCalories,
      isTrainingDay: isTrainingDay,
    );

    final meals = _mealPlanner.plan(
      profile: profile,
      targets: macros,
      isTrainingDay: isTrainingDay,
      planningDate: day,
      recentLogs: recentLogs,
    );

    final country = _foodKnowledgeBase.resolvedCountry(profile.country);
    final status = _resolveStatus(
      profile: profile,
      isTrainingDay: isTrainingDay,
      target: calorieEstimate.targetCalories,
      maintenance: calorieEstimate.maintenanceCalories,
    );

    final reasons = <String>[
      ...calorieEstimate.reasons,
      'Macros set to P${macros.proteinG}g / C${macros.carbsG}g / F${macros.fatG}g.',
      if (macros.waterMl != null)
        'Hydration target: ${(macros.waterMl! / 1000).toStringAsFixed(1)} L.',
      'Meals selected from $country food knowledge base (${meals.length} meals).',
      if (recentLogs.isNotEmpty)
        'Recent nutrition history was used to reduce meal repetition.',
      'Status: ${status.displayName}.',
    ];

    return NutritionPlan(
      userId: profile.userId,
      date: day,
      targets: macros,
      maintenanceCalories: calorieEstimate.maintenanceCalories.toDouble(),
      status: status,
      meals: meals,
      country: country,
      isTrainingDay: isTrainingDay,
      reasons: reasons,
    );
  }

  Future<List<NutritionLog>> _loadRecentLogsForPlanning({
    required String userId,
    required DateTime planningDate,
    int days = 7,
  }) async {
    final repo = _nutritionRepository;
    if (repo == null || days <= 0) return const [];

    final logs = <NutritionLog>[];
    final startDate = DateTime(
      planningDate.year,
      planningDate.month,
      planningDate.day,
    );

    for (var offset = 1; offset <= days; offset++) {
      final day = startDate.subtract(Duration(days: offset));
      logs.addAll(
        await repo.getNutritionLogsForDay(userId, day),
      );
    }

    return logs;
  }

  NutritionStatus _resolveStatus({
    required HealthProfile profile,
    required bool isTrainingDay,
    required int target,
    required int maintenance,
  }) {
    if (isTrainingDay && target > maintenance) {
      return NutritionStatus.trainingDayBoost;
    }
    if (target < maintenance * 0.95) return NutritionStatus.deficit;
    if (target > maintenance * 1.05) return NutritionStatus.surplus;
    if (!isTrainingDay) return NutritionStatus.recoverySupport;
    return NutritionStatus.onTarget;
  }
}
