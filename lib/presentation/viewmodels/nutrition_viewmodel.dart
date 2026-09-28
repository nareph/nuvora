import 'package:flutter/foundation.dart';
import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/domain/entities/food_item.dart';
import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/entities/logged_food_portion.dart';
import 'package:gymgenius/domain/entities/meal.dart';
import 'package:gymgenius/domain/entities/meal_portion_option.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/entities/nutrition_adherence_snapshot.dart';
import 'package:gymgenius/domain/entities/nutrition_plan.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/repositories/health_repository.dart';
import 'package:gymgenius/domain/repositories/nutrition_repository.dart';
import 'package:gymgenius/domain/repositories/user_repository.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/builders/meal_log_builder.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/food_knowledge_base.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/models/meal_template.dart';
import 'package:gymgenius/engines/nutrition_engine/nutrition_engine.dart';
import 'package:gymgenius/engines/nutrition_engine/trackers/adherence_tracker.dart';

enum NutritionUiState { initial, loading, ready, error }

class NutritionViewModel extends ChangeNotifier {
  NutritionPlan _plan;
  NutritionPlan get plan => _plan;
  final UserRepository _userRepository;
  final HealthRepository _healthRepository;
  final NutritionRepository _nutritionRepository;
  final NutritionEngine _nutritionEngine;
  final FoodKnowledgeBase _foodKnowledgeBase;
  final MealLogBuilder _mealLogBuilder;
  final AdherenceTracker _adherenceTracker;

  NutritionViewModel({
    required NutritionPlan plan,
    required UserRepository userRepository,
    required HealthRepository healthRepository,
    required NutritionRepository nutritionRepository,
    required NutritionEngine nutritionEngine,
    FoodKnowledgeBase foodKnowledgeBase = const FoodKnowledgeBase(),
    MealLogBuilder mealLogBuilder = const MealLogBuilder(),
    AdherenceTracker adherenceTracker = const AdherenceTracker(),
  })  : _plan = plan,
        _userRepository = userRepository,
        _healthRepository = healthRepository,
        _nutritionRepository = nutritionRepository,
        _nutritionEngine = nutritionEngine,
        _foodKnowledgeBase = foodKnowledgeBase,
        _mealLogBuilder = mealLogBuilder,
        _adherenceTracker = adherenceTracker;

  NutritionUiState _state = NutritionUiState.initial;
  NutritionUiState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  HealthProfile? _profile;
  HealthProfile? get profile => _profile;

  List<NutritionLog> _logs = const [];
  List<NutritionLog> get logs => _logs;

  NutritionAdherenceSnapshot? _nutritionSnapshot;
  NutritionAdherenceSnapshot? get nutritionSnapshot => _nutritionSnapshot;

  List<FoodItem> _availableFoods = const [];
  List<FoodItem> get availableFoods => _availableFoods;

  // Full meal catalog for [plan.country] — NOT just today's suggested
  // meals (those live in plan.meals, already portion-scaled to target
  // calories). Lets the user log any known dish, not only what the
  // planner picked for today. See "database meal" logging tier.
  List<MealTemplate> _availableMealTemplates = const [];
  List<MealTemplate> get availableMealTemplates => _availableMealTemplates;

  MacroTargets get loggedTotals => _mealLogBuilder.sumLoggedMacros(_logs);

  double get adherenceScore => _adherenceTracker.scoreFromLogs(
        targetCalories: plan.targets.calories,
        logs: _logs,
      );

  bool isMealLogged(Meal meal) => _logs.any((log) => log.planMealId == meal.id);

  bool isChangingMeal(String mealId) => _changingMealIds.contains(mealId);

  final Set<String> _changingMealIds = <String>{};

  /// Replaces one suggested meal and persists the updated daily plan.
  ///
  /// A logged meal is intentionally not replaceable: the log represents what
  /// the user actually ate and must remain consistent with the plan history.
  Future<bool> replaceSuggestedMeal(Meal meal) async {
    final profile = _profile;
    if (profile == null || isChangingMeal(meal.id)) return false;

    if (_logs.any((log) => log.planMealId == meal.id)) return false;

    _changingMealIds.add(meal.id);
    notifyListeners();

    try {
      final updatedPlan = await _nutritionEngine.replaceSuggestedMeal(
        plan: _plan,
        profile: profile,
        meal: meal,
      );
      _plan = updatedPlan;
      _refreshNutritionSnapshot();
      return true;
    } catch (e, s) {
      Log.error(
        'NutritionViewModel.replaceSuggestedMeal failed',
        error: e,
        stackTrace: s,
      );
      return false;
    } finally {
      _changingMealIds.remove(meal.id);
      notifyListeners();
    }
  }

  Future<void> load() async {
    _state = NutritionUiState.loading;
    notifyListeners();
    try {
      final user = await _userRepository.getCurrentUser();
      if (user == null) throw Exception('Not authenticated');

      _profile = await _healthRepository.getCurrentProfile();
      _availableFoods = _foodKnowledgeBase.foodsForCountry(plan.country);
      _availableMealTemplates =
          _foodKnowledgeBase.mealTemplatesForCountry(plan.country);
      _logs = await _nutritionRepository.getNutritionLogsForDay(
        user.id,
        plan.date,
      );
      _refreshNutritionSnapshot();
      _state = NutritionUiState.ready;
    } catch (e, s) {
      Log.error('NutritionViewModel.load failed', error: e, stackTrace: s);
      _errorMessage = e.toString();
      _state = NutritionUiState.error;
    }
    notifyListeners();
  }

  Future<void> logSuggestedMeal(Meal meal) async {
    final profile = _profile;
    if (profile == null) return;

    final log = _mealLogBuilder.fromPlanMeal(
      meal: meal,
      userId: profile.userId,
    );
    await _persistLog(log, profile);
  }

  /// Logs an existing [MealTemplate] from the full catalog — the
  /// "database meal" tier, distinct from today's plan suggestions.
  ///
  /// [portion] is optional so all existing callers remain valid. When it is
  /// supplied, the template macros are scaled to that human-friendly size.
  Future<void> logDatabaseMeal({
    required MealTemplate template,
    required MealType mealType,
    MealPortionOption? portion,
  }) async {
    final profile = _profile;
    if (profile == null) return;

    final log = _mealLogBuilder.fromMealTemplate(
      template: template,
      mealType: mealType,
      userId: profile.userId,
      portion: portion,
    );
    await _persistLog(log, profile);
  }

  Future<void> logComposedMeal({
    required String name,
    required MealType mealType,
    required List<LoggedFoodPortion> portions,
  }) async {
    final profile = _profile;
    if (profile == null || portions.isEmpty) return;

    final log = _mealLogBuilder.fromFoodPortions(
      userId: profile.userId,
      name: name,
      mealType: mealType,
      portions: portions,
      availableFoods: _availableFoods,
    );
    await _persistLog(log, profile);
  }

  Future<void> logManualMeal({
    required String name,
    required MealType mealType,
    required MacroTargets macros,
  }) async {
    final profile = _profile;
    if (profile == null || macros.calories <= 0) return;

    final log = _mealLogBuilder.fromManual(
      userId: profile.userId,
      name: name,
      mealType: mealType,
      macros: macros,
    );
    await _persistLog(log, profile);
  }

  Future<void> deleteLog(String logId) async {
    final profile = _profile;
    if (profile == null) return;

    await _nutritionEngine.deleteMealLog(
      logId: logId,
      plan: plan,
      profile: profile,
    );
    _logs = await _nutritionRepository.getNutritionLogsForDay(
      profile.userId,
      plan.date,
    );
    _refreshNutritionSnapshot();
    notifyListeners();
  }

  Future<void> _persistLog(NutritionLog log, HealthProfile profile) async {
    await _nutritionEngine.logMeal(
      log: log,
      plan: plan,
      profile: profile,
    );
    _logs = await _nutritionRepository.getNutritionLogsForDay(
      profile.userId,
      plan.date,
    );
    _refreshNutritionSnapshot();
    notifyListeners();
  }

  /// Rebuilds the synthesized nutrition state from the current plan and logs.
  void _refreshNutritionSnapshot() {
    _nutritionSnapshot = _nutritionEngine.buildAdherenceSnapshot(
      plan: _plan,
      logs: _logs,
    );
  }

}