import 'package:flutter_test/flutter_test.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/enums/budget_level.dart';
import 'package:gymgenius/domain/enums/fitness_goal.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/nutrition_engine.dart';
import 'package:gymgenius/engines/nutrition_engine/planners/meal_planner.dart';

import 'calorie_macro_test.dart';

void main() {
  group('MealPlanner.replaceMeal', () {
    test('changes only the requested slot and keeps other meals intact', () {
      final profile = buildTestProfile(
        goal: FitnessGoal.buildMuscle,
        budget: BudgetLevel.high,
      ).copyWith(
        lifestyle: buildTestProfile(
          goal: FitnessGoal.buildMuscle,
          budget: BudgetLevel.high,
        ).lifestyle.copyWith(trainingTime: 18),
      );
      const targets = MacroTargets(
        calories: 2800,
        proteinG: 160,
        carbsG: 320,
        fatG: 80,
      );
      final date = DateTime(2026, 9, 24);
      const planner = MealPlanner();

      final meals = planner.plan(
        profile: profile,
        targets: targets,
        isTrainingDay: true,
        planningDate: date,
      );
      final target = meals.firstWhere(
        (meal) => meal.type == MealType.lunch,
      );

      final replacement = planner.replaceMeal(
        profile: profile,
        targets: targets,
        isTrainingDay: true,
        planningDate: date,
        currentMeal: target,
        currentMeals: meals,
      );

      expect(replacement.type, target.type);
      expect(replacement.id, isNot(target.id));
      expect(replacement.macros.calories, target.macros.calories);
      expect(
        meals.where((meal) => meal.id == target.id).length,
        1,
      );
      expect(
        replacement.id,
        isNot(anyOf(<Matcher>[for (final meal in meals) equals(meal.id)])),
      );
    });

    test('recent history is considered for replacement', () {
      final profile = buildTestProfile();
      const targets = MacroTargets(
        calories: 2500,
        proteinG: 150,
        carbsG: 300,
        fatG: 70,
      );
      final date = DateTime(2026, 9, 24);
      const planner = MealPlanner();
      final meals = planner.plan(
        profile: profile,
        targets: targets,
        isTrainingDay: false,
        planningDate: date,
      );
      final target = meals.first;

      final recent = [
        NutritionLog(
          id: 'recent_${target.id}',
          userId: profile.userId,
          name: target.name,
          source: NutritionLogSource.template,
          mealType: target.type,
          macros: target.macros,
          loggedAt: date.subtract(const Duration(days: 1)),
          templateId: target.id.replaceFirst('_${target.type.value}', ''),
          planMealId: target.id,
        ),
      ];

      final replacement = planner.replaceMeal(
        profile: profile,
        targets: targets,
        isTrainingDay: false,
        planningDate: date,
        currentMeal: target,
        currentMeals: meals,
        recentLogs: recent,
      );

      expect(replacement.name, isNot(target.name));
    });
  });

  test('NutritionEngine.replaceSuggestedMeal returns an updated plan', () async {
    final profile = buildTestProfile();
    final engine = NutritionEngine();
    final date = DateTime(2026, 9, 24);
    final plan = engine.computeDailyPlanSync(
      profile: profile,
      isTrainingDay: false,
      date: date,
    );
    final target = plan.meals.first;

    final updated = await engine.replaceSuggestedMeal(
      plan: plan,
      profile: profile,
      meal: target,
    );

    expect(updated.meals.length, plan.meals.length);
    expect(
      updated.meals.where((meal) => meal.type == target.type).single.id,
      isNot(target.id),
    );
    expect(
      updated.meals.where((meal) => meal.id == target.id),
      isEmpty,
    );
  });
}
