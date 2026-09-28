import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/entities/meal.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/enums/meal_objective.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/food_knowledge_base.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/models/meal_template.dart';

/// Builds a daily meal structure from macro targets and local foods.
///
/// Selection is deliberately deterministic. The planner does not use an
/// uncontrolled Random() to create variety. Instead, the planning date and
/// slot participate in a stable rotation key, while recent nutrition logs
/// receive a repetition penalty and are progressively relaxed only when the
/// compatible catalog is too small.
class MealPlanner {
  final FoodKnowledgeBase _foodKnowledgeBase;

  const MealPlanner({
    FoodKnowledgeBase foodKnowledgeBase = const FoodKnowledgeBase(),
  }) : _foodKnowledgeBase = foodKnowledgeBase;

  List<Meal> plan({
    required HealthProfile profile,
    required MacroTargets targets,
    required bool isTrainingDay,
    DateTime? planningDate,
    Iterable<NutritionLog> recentLogs = const <NutritionLog>[],
  }) {
    final date = _dateOnly(planningDate ?? DateTime.now());
    final slots = _mealSlots(
      isTrainingDay: isTrainingDay,
      trainingHour: profile.lifestyle.trainingTime,
    );

    final templates = _foodKnowledgeBase.filterTemplates(
      country: profile.country,
      budget: profile.lifestyle.budget,
      restrictions: profile.lifestyle.foodRestrictions,
      preferredFoods: profile.lifestyle.foodPreferences,
    );

    if (templates.isEmpty) {
      return _fallbackMeals(targets, slots);
    }

    final recentHistory = _buildRecentHistory(
      logs: recentLogs,
      planningDate: date,
    );

    final meals = <Meal>[];
    final calorieShares = _calorieShares(slots.length, isTrainingDay);
    final usedIds = <String>{};

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final share = calorieShares[i];
      final slotCalories = (targets.calories * share).round();

      final template = _pickTemplate(
        templates: templates,
        slot: slot,
        isTrainingDay: isTrainingDay,
        usedIds: usedIds,
        recentHistory: recentHistory,
        planningDate: date,
        preferredFoods: profile.lifestyle.foodPreferences,
      );

      usedIds.add(template.id);

      final scaled = _scaleMacros(template.baseMacros, slotCalories);
      meals.add(
        Meal(
          id: '${template.id}_${slot.value}',
          name: template.name,
          type: slot,
          objective: template.objective,
          ingredients: List<String>.from(template.ingredientNames),
          macros: scaled,
          timingNote: _timingNote(slot, profile.lifestyle.trainingTime),
          reason: _mealReason(slot, template.objective, isTrainingDay),
        ),
      );
    }

    return meals;
  }

  /// Selects one deterministic replacement for an existing plan meal.
  ///
  /// The replacement keeps the same meal slot and calorie share while
  /// excluding all other meals currently present in the plan. Recent logs,
  /// restrictions, budget, preferences and slot/objective compatibility are
  /// still applied through the same scoring pipeline as the daily planner.
  Meal replaceMeal({
    required HealthProfile profile,
    required MacroTargets targets,
    required bool isTrainingDay,
    required DateTime planningDate,
    required Meal currentMeal,
    required List<Meal> currentMeals,
    Iterable<NutritionLog> recentLogs = const <NutritionLog>[],
  }) {
    final date = _dateOnly(planningDate);
    final slots = _mealSlots(
      isTrainingDay: isTrainingDay,
      trainingHour: profile.lifestyle.trainingTime,
    );
    final slotIndex = slots.indexOf(currentMeal.type);

    if (slotIndex == -1) {
      throw StateError(
        'Cannot replace meal: ${currentMeal.type.value} is not a valid slot '
        'for this plan.',
      );
    }

    final templates = _foodKnowledgeBase.filterTemplates(
      country: profile.country,
      budget: profile.lifestyle.budget,
      restrictions: profile.lifestyle.foodRestrictions,
      preferredFoods: profile.lifestyle.foodPreferences,
    );

    if (templates.isEmpty) {
      throw StateError('No compatible meal templates are available.');
    }

    final recentHistory = _buildRecentHistory(
      logs: recentLogs,
      planningDate: date,
    );

    final currentTemplateId =
        _templateIdFromMealId(currentMeal.id, currentMeal.type);
    final usedIds = <String>{};
    for (final meal in currentMeals) {
      if (meal.id == currentMeal.id) continue;
      final templateId = _templateIdFromMealId(meal.id, meal.type);
      if (templateId != null) {
        usedIds.add(templateId);
      }
    }
    if (currentTemplateId != null) {
      usedIds.add(currentTemplateId);
    }

    final objectives = _objectivesForSlot(currentMeal.type, isTrainingDay);
    final stages = <List<MealTemplate> Function()>[
      () => templates.where((template) {
            return !usedIds.contains(template.id) &&
                !_isRecent(template, recentHistory) &&
                _slotScore(template, currentMeal.type, objectives) > 0 &&
                _objectiveScore(template, objectives) >= 40;
          }).toList(),
      () => templates.where((template) {
            return !usedIds.contains(template.id) &&
                !_isRecent(template, recentHistory) &&
                _slotScore(template, currentMeal.type, objectives) > 0;
          }).toList(),
      () => templates.where((template) {
            return !usedIds.contains(template.id) &&
                !_isRecent(template, recentHistory) &&
                _objectiveScore(template, objectives) >= 40;
          }).toList(),
      () => templates.where((template) {
            return !usedIds.contains(template.id) &&
                !_isRecent(template, recentHistory);
          }).toList(),
      () => templates
          .where((template) => !usedIds.contains(template.id))
          .toList(),
    ];

    MealTemplate? replacementTemplate;
    for (final buildPool in stages) {
      final pool = buildPool();
      if (pool.isEmpty) continue;

      replacementTemplate = _bestTemplate(
        pool: pool,
        slot: currentMeal.type,
        objectives: objectives,
        recentHistory: recentHistory,
        planningDate: date,
        preferredFoods: profile.lifestyle.foodPreferences,
      );
      break;
    }

    if (replacementTemplate == null) {
      throw StateError('No compatible replacement meal is available.');
    }

    final shares = _calorieShares(slots.length, isTrainingDay);
    final slotCalories = (targets.calories * shares[slotIndex]).round();
    final scaled = _scaleMacros(
      replacementTemplate.baseMacros,
      slotCalories,
    );

    return Meal(
      id: '${replacementTemplate.id}_${currentMeal.type.value}',
      name: replacementTemplate.name,
      type: currentMeal.type,
      objective: replacementTemplate.objective,
      ingredients: List<String>.from(replacementTemplate.ingredientNames),
      macros: scaled,
      timingNote: _timingNote(
        currentMeal.type,
        profile.lifestyle.trainingTime,
      ),
      reason: _mealReason(
        currentMeal.type,
        replacementTemplate.objective,
        isTrainingDay,
      ),
    );
  }

  List<MealType> _mealSlots({
    required bool isTrainingDay,
    int? trainingHour,
  }) {
    if (!isTrainingDay) {
      return const [
        MealType.breakfast,
        MealType.lunch,
        MealType.snack,
        MealType.dinner,
      ];
    }

    final hour = trainingHour ?? 17;
    if (hour <= 10) {
      return const [
        MealType.preWorkout,
        MealType.postWorkout,
        MealType.lunch,
        MealType.snack,
        MealType.dinner,
      ];
    }
    if (hour >= 18) {
      return const [
        MealType.breakfast,
        MealType.lunch,
        MealType.snack,
        MealType.preWorkout,
        MealType.postWorkout,
      ];
    }
    return const [
      MealType.breakfast,
      MealType.lunch,
      MealType.preWorkout,
      MealType.postWorkout,
      MealType.dinner,
    ];
  }

  List<double> _calorieShares(int count, bool isTrainingDay) {
    switch (count) {
      case 3:
        return const [0.30, 0.40, 0.30];
      case 4:
        return isTrainingDay
            ? const [0.25, 0.30, 0.15, 0.30]
            : const [0.25, 0.35, 0.10, 0.30];
      case 5:
        return const [0.20, 0.25, 0.15, 0.20, 0.20];
      default:
        return List.filled(count, 1 / count);
    }
  }

  MealTemplate _pickTemplate({
    required List<MealTemplate> templates,
    required MealType slot,
    required bool isTrainingDay,
    required Set<String> usedIds,
    required _RecentHistory recentHistory,
    required DateTime planningDate,
    required List<String> preferredFoods,
  }) {
    final objectives = _objectivesForSlot(slot, isTrainingDay);

    // Progressive fallback:
    // 1. slot + objective + not recently used
    // 2. slot + not recently used
    // 3. objective + not recently used
    // 4. any compatible + not recently used
    // 5. any compatible, including recent history, if necessary
    final stages = <List<MealTemplate> Function()>[
      () => templates.where((t) {
            return !usedIds.contains(t.id) &&
                !_isRecent(t, recentHistory) &&
                _slotScore(t, slot, objectives) > 0 &&
                _objectiveScore(t, objectives) >= 40;
          }).toList(),
      () => templates.where((t) {
            return !usedIds.contains(t.id) &&
                !_isRecent(t, recentHistory) &&
                _slotScore(t, slot, objectives) > 0;
          }).toList(),
      () => templates.where((t) {
            return !usedIds.contains(t.id) &&
                !_isRecent(t, recentHistory) &&
                _objectiveScore(t, objectives) >= 40;
          }).toList(),
      () => templates.where((t) {
            return !usedIds.contains(t.id) && !_isRecent(t, recentHistory);
          }).toList(),
      () => templates.where((t) => !usedIds.contains(t.id)).toList(),
    ];

    for (final buildPool in stages) {
      final pool = buildPool();
      if (pool.isEmpty) continue;

      return _bestTemplate(
        pool: pool,
        slot: slot,
        objectives: objectives,
        recentHistory: recentHistory,
        planningDate: planningDate,
        preferredFoods: preferredFoods,
      );
    }

    // This is only reachable when every template was already used in the
    // same day. Keeping the previous behavior is safer than returning null.
    return _bestTemplate(
      pool: templates,
      slot: slot,
      objectives: objectives,
      recentHistory: recentHistory,
      planningDate: planningDate,
      preferredFoods: preferredFoods,
    );
  }

  MealTemplate _bestTemplate({
    required List<MealTemplate> pool,
    required MealType slot,
    required List<MealObjective> objectives,
    required _RecentHistory recentHistory,
    required DateTime planningDate,
    required List<String> preferredFoods,
  }) {
    MealTemplate best = pool.first;
    var bestScore = _templateScore(
      template: best,
      slot: slot,
      objectives: objectives,
      recentHistory: recentHistory,
      planningDate: planningDate,
      preferredFoods: preferredFoods,
    );

    for (final candidate in pool.skip(1)) {
      final score = _templateScore(
        template: candidate,
        slot: slot,
        objectives: objectives,
        recentHistory: recentHistory,
        planningDate: planningDate,
        preferredFoods: preferredFoods,
      );

      if (score > bestScore ||
          (score == bestScore &&
              _rotationKey(candidate.id, slot, planningDate) >
                  _rotationKey(best.id, slot, planningDate))) {
        best = candidate;
        bestScore = score;
      }
    }

    return best;
  }

  int _templateScore({
    required MealTemplate template,
    required MealType slot,
    required List<MealObjective> objectives,
    required _RecentHistory recentHistory,
    required DateTime planningDate,
    required List<String> preferredFoods,
  }) {
    var score = 0;

    score += _slotScore(template, slot, objectives);
    score += _objectiveScore(template, objectives);
    score += _preferredFoodScore(template, preferredFoods);

    // Recent meals are strongly discouraged. The progressive fallback allows
    // them only after all non-recent compatible options are exhausted.
    score += _recentPenalty(template, recentHistory);

    // Stable daily variation. This changes with date + slot + template while
    // remaining deterministic and testable.
    score += _rotationKey(template.id, slot, planningDate) % 61;

    return score;
  }

  int _slotScore(
    MealTemplate template,
    MealType slot,
    List<MealObjective> objectives,
  ) {
    final tags = template.tags.map((tag) => tag.toLowerCase()).toSet();

    if (tags.contains(slot.value.toLowerCase())) {
      return 100;
    }

    switch (slot) {
      case MealType.breakfast:
        if (tags.contains('morning')) return 75;
        break;
      case MealType.lunch:
        if (tags.contains('main')) return 75;
        break;
      case MealType.dinner:
        if (tags.contains('evening')) return 75;
        break;
      case MealType.snack:
        if (tags.contains('light')) return 80;
        break;
      case MealType.preWorkout:
        if (tags.contains('preworkout') ||
            tags.contains('pre-workout') ||
            tags.contains('pre_workout')) {
          return 100;
        }
        if (tags.contains('snack') || tags.contains('light')) return 65;
        if (tags.contains('staple') &&
            objectives.contains(MealObjective.highEnergy)) {
          return 60;
        }
        break;
      case MealType.postWorkout:
        if (tags.contains('postworkout') ||
            tags.contains('post-workout') ||
            tags.contains('post_workout')) {
          return 100;
        }
        if (tags.contains('recovery')) return 80;
        break;
    }

    // Soft compatibility keeps the planner useful with a small knowledge
    // base while still letting explicit slot tags win.
    if (objectives.contains(template.objective)) return 35;
    return 0;
  }

  int _objectiveScore(
    MealTemplate template,
    List<MealObjective> objectives,
  ) {
    if (objectives.isEmpty) return 0;
    if (template.objective == objectives.first) return 80;
    if (objectives.skip(1).contains(template.objective)) return 50;
    return 0;
  }

  int _preferredFoodScore(
    MealTemplate template,
    List<String> preferredFoods,
  ) {
    if (preferredFoods.isEmpty) return 0;

    final ingredients =
        template.ingredientNames.map((value) => value.toLowerCase()).toList();

    var score = 0;
    for (final preference in preferredFoods) {
      final normalized = preference.trim().toLowerCase();
      if (normalized.isEmpty) continue;

      if (ingredients.any(
        (ingredient) =>
            ingredient.contains(normalized) || normalized.contains(ingredient),
      )) {
        score += 25;
      }
    }

    return score;
  }

  bool _isRecent(MealTemplate template, _RecentHistory history) {
    return history.templateAgeDays.containsKey(template.id) ||
        history.normalizedNames.contains(_normalizeName(template.name));
  }

  int _recentPenalty(
    MealTemplate template,
    _RecentHistory history,
  ) {
    final ages = <int>[];
    final templateAge = history.templateAgeDays[template.id];
    if (templateAge != null) ages.add(templateAge);

    final nameAge = history.nameAgeDays[_normalizeName(template.name)];
    if (nameAge != null) ages.add(nameAge);

    if (ages.isEmpty) return 0;

    final daysAgo = ages.reduce((a, b) => a < b ? a : b);
    final penalty = (140 - (daysAgo * 15)).clamp(20, 140).toInt();
    return -penalty;
  }

  List<MealObjective> _objectivesForSlot(
    MealType slot,
    bool isTrainingDay,
  ) {
    switch (slot) {
      case MealType.breakfast:
        return const [MealObjective.highProtein, MealObjective.light];
      case MealType.lunch:
        return isTrainingDay
            ? const [MealObjective.highEnergy, MealObjective.highProtein]
            : const [MealObjective.highProtein, MealObjective.recovery];
      case MealType.snack:
        return const [MealObjective.light, MealObjective.recovery];
      case MealType.preWorkout:
        return const [MealObjective.highEnergy, MealObjective.light];
      case MealType.postWorkout:
        return const [MealObjective.recovery, MealObjective.highProtein];
      case MealType.dinner:
        return isTrainingDay
            ? const [MealObjective.recovery, MealObjective.light]
            : const [MealObjective.light, MealObjective.recovery];
    }
  }

  MacroTargets _scaleMacros(MacroTargets base, int targetCalories) {
    if (base.calories <= 0) {
      return MacroTargets(
        calories: targetCalories,
        proteinG: (targetCalories * 0.3 / 4).round(),
        carbsG: (targetCalories * 0.4 / 4).round(),
        fatG: (targetCalories * 0.3 / 9).round(),
      );
    }
    final factor = targetCalories / base.calories;
    return MacroTargets(
      calories: targetCalories,
      proteinG: (base.proteinG * factor).round().clamp(5, 200),
      carbsG: (base.carbsG * factor).round().clamp(5, 300),
      fatG: (base.fatG * factor).round().clamp(2, 120),
    );
  }

  String? _timingNote(MealType slot, int? trainingHour) {
    switch (slot) {
      case MealType.preWorkout:
        return trainingHour == null
            ? 'Eat 60–90 minutes before training'
            : 'Around ${(trainingHour - 1).clamp(5, 22)}:00 before training';
      case MealType.postWorkout:
        return 'Within 60 minutes after training';
      case MealType.breakfast:
        return 'Morning meal';
      case MealType.lunch:
        return 'Midday meal';
      case MealType.dinner:
        return 'Evening meal';
      case MealType.snack:
        return 'Between meals';
    }
  }

  String _mealReason(
    MealType slot,
    MealObjective objective,
    bool isTrainingDay,
  ) {
    final day = isTrainingDay ? 'training day' : 'rest day';
    return '${slot.displayName} supports $day needs '
        '(${objective.displayName.toLowerCase()}).';
  }

  List<Meal> _fallbackMeals(MacroTargets targets, List<MealType> slots) {
    final shares = _calorieShares(slots.length, false);
    return [
      for (var i = 0; i < slots.length; i++)
        Meal(
          id: 'fallback_${slots[i].value}',
          name: 'Balanced local meal',
          type: slots[i],
          objective: MealObjective.highEnergy,
          ingredients: const ['Rice', 'Beans', 'Vegetables'],
          macros: MacroTargets(
            calories: (targets.calories * shares[i]).round(),
            proteinG: (targets.proteinG * shares[i]).round(),
            carbsG: (targets.carbsG * shares[i]).round(),
            fatG: (targets.fatG * shares[i]).round(),
          ),
          reason: 'Fallback meal — no matching local templates after filters.',
        ),
    ];
  }

  _RecentHistory _buildRecentHistory({
    required Iterable<NutritionLog> logs,
    required DateTime planningDate,
  }) {
    final templateAgeDays = <String, int>{};
    final nameAgeDays = <String, int>{};

    for (final log in logs) {
      final logDate = _dateOnly(log.loggedAt);
      final difference = planningDate.difference(logDate).inDays;
      if (difference < 0 || difference > 7) continue;

      final templateId = log.templateId;
      if (templateId != null && templateId.isNotEmpty) {
        final current = templateAgeDays[templateId];
        if (current == null || difference < current) {
          templateAgeDays[templateId] = difference;
        }
      }

      final normalizedName = _normalizeName(log.name);
      if (normalizedName.isNotEmpty) {
        final current = nameAgeDays[normalizedName];
        if (current == null || difference < current) {
          nameAgeDays[normalizedName] = difference;
        }
      }
    }

    return _RecentHistory(
      templateAgeDays: templateAgeDays,
      nameAgeDays: nameAgeDays,
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  int _rotationKey(String templateId, MealType slot, DateTime planningDate) {
    final input =
        '${planningDate.year}-${planningDate.month}-${planningDate.day}|'
        '${slot.value}|$templateId';

    // Stable FNV-1a-style hash. Do not use Dart's hashCode because stable
    // cross-run ordering is part of the planner contract.
    var hash = 2166136261;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  String? _templateIdFromMealId(String mealId, MealType type) {
    final suffix = '_${type.value}';
    if (mealId.endsWith(suffix)) {
      return mealId.substring(0, mealId.length - suffix.length);
    }
    return null;
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _RecentHistory {
  final Map<String, int> templateAgeDays;
  final Map<String, int> nameAgeDays;

  const _RecentHistory({
    required this.templateAgeDays,
    required this.nameAgeDays,
  });

  Set<String> get normalizedNames => nameAgeDays.keys.toSet();
}
