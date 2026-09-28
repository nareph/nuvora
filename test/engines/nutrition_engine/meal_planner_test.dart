import 'package:flutter_test/flutter_test.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/enums/budget_level.dart';
import 'package:gymgenius/domain/enums/fitness_goal.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/food_knowledge_base.dart';
import 'package:gymgenius/engines/nutrition_engine/planners/meal_planner.dart';

import 'calorie_macro_test.dart';

void main() {
  group('FoodKnowledgeBase', () {
    const fkb = FoodKnowledgeBase();

    test('falls back unknown country to Cameroon', () {
      expect(fkb.resolvedCountry('France'), 'Cameroon');
      expect(fkb.resolvedCountry('Cameroun'), 'Cameroon');
      expect(fkb.foodsForCountry('Nigeria'), isNotEmpty);
    });

    test('filters peanut-restricted meals', () {
      final filtered = fkb.filterTemplates(
        country: 'Cameroon',
        budget: BudgetLevel.high,
        restrictions: const ['peanut'],
      );
      expect(filtered, isNotEmpty);
      expect(
        filtered.every((m) => !m.allergens.contains('peanut')),
        isTrue,
      );
    });

    test('low budget excludes medium-budget meals', () {
      final low = fkb.filterTemplates(
        country: 'Cameroon',
        budget: BudgetLevel.low,
      );
      final high = fkb.filterTemplates(
        country: 'Cameroon',
        budget: BudgetLevel.high,
      );
      final medium = fkb.filterTemplates(
        country: 'Cameroon',
        budget: BudgetLevel.medium,
      );
      expect(low.length, lessThan(high.length));
      expect(low.length, lessThanOrEqualTo(medium.length));
      expect(medium.length, lessThanOrEqualTo(high.length));
      expect(
        low.every((m) => m.minBudget == BudgetLevel.low),
        isTrue,
      );
    });

    test('preferred foods bias meal selection', () {
      final lowProfile = buildTestProfile(
        budget: BudgetLevel.high,
        restrictions: const [],
      );
      final preferredProfile = lowProfile.copyWith(
        lifestyle: lowProfile.lifestyle.copyWith(
          foodPreferences: const ['rice'],
        ),
      );

      final planner = MealPlanner();
      final meals = planner.plan(
        profile: preferredProfile,
        planningDate: DateTime(2026, 9, 24),
        targets: const MacroTargets(
          calories: 2500,
          proteinG: 150,
          carbsG: 300,
          fatG: 70,
        ),
        isTrainingDay: true,
      );

      final anyRice = meals.any((m) =>
          m.ingredients.join(' ').toLowerCase().contains('rice'));
      expect(anyRice, isTrue);
    });
  });

  group('MealPlanner', () {
    const planner = MealPlanner();

    test('training day includes pre/post workout slots when evening training', () {
      final profile = buildTestProfile(goal: FitnessGoal.buildMuscle);
      final withTrainingTime = profile.copyWith(
        lifestyle: profile.lifestyle.copyWith(trainingTime: 18),
      );
      final meals = planner.plan(
        profile: withTrainingTime,
        planningDate: DateTime(2026, 9, 24),
        targets: const MacroTargets(
          calories: 2800,
          proteinG: 160,
          carbsG: 320,
          fatG: 80,
          waterMl: 3000,
        ),
        isTrainingDay: true,
      );

      expect(meals.length, greaterThanOrEqualTo(4));
      expect(meals.any((m) => m.type == MealType.preWorkout), isTrue);
      expect(meals.any((m) => m.type == MealType.postWorkout), isTrue);
      expect(meals.every((m) => m.ingredients.isNotEmpty), isTrue);
    });

    test('rest day has four standard meals without workout slots', () {
      final profile = buildTestProfile();
      final meals = planner.plan(
        profile: profile,
        planningDate: DateTime(2026, 9, 24),
        targets: const MacroTargets(
          calories: 2400,
          proteinG: 140,
          carbsG: 280,
          fatG: 70,
          waterMl: 2800,
        ),
        isTrainingDay: false,
      );

      expect(meals.length, 4);
      expect(meals.any((m) => m.type == MealType.preWorkout), isFalse);
      expect(meals.map((m) => m.type).toSet().length, meals.length);
    });

    test('respects fish restriction', () {
      final profile = buildTestProfile(restrictions: const ['fish']);
      final meals = planner.plan(
        profile: profile,
        planningDate: DateTime(2026, 9, 24),
        targets: const MacroTargets(
          calories: 2500,
          proteinG: 150,
          carbsG: 300,
          fatG: 70,
        ),
        isTrainingDay: true,
      );

      for (final meal in meals) {
        final blob = meal.ingredients.join(' ').toLowerCase();
        expect(blob.contains('fish'), isFalse);
        expect(blob.contains('sardine'), isFalse);
      }
    });

    test('different planning dates can rotate compatible meals', () {
      final profile = buildTestProfile();
      const targets = MacroTargets(
        calories: 2500,
        proteinG: 150,
        carbsG: 300,
        fatG: 70,
      );

      final first = planner.plan(
        profile: profile,
        targets: targets,
        isTrainingDay: true,
        planningDate: DateTime(2026, 9, 24),
      );
      final second = planner.plan(
        profile: profile,
        targets: targets,
        isTrainingDay: true,
        planningDate: DateTime(2026, 9, 30),
      );

      expect(
        first.map((meal) => meal.name).toList(),
        isNot(equals(second.map((meal) => meal.name).toList())),
      );
    });

    test('same inputs and planning date produce the same plan', () {
      final profile = buildTestProfile();
      const targets = MacroTargets(
        calories: 2500,
        proteinG: 150,
        carbsG: 300,
        fatG: 70,
      );
      final date = DateTime(2026, 9, 24);

      final first = planner.plan(
        profile: profile,
        targets: targets,
        isTrainingDay: true,
        planningDate: date,
      );
      final second = planner.plan(
        profile: profile,
        targets: targets,
        isTrainingDay: true,
        planningDate: date,
      );

      expect(
        first.map((meal) => meal.name).toList(),
        second.map((meal) => meal.name).toList(),
      );
    });

    test('recent template meals are avoided when compatible alternatives exist', () {
      final profile = buildTestProfile();
      final date = DateTime(2026, 9, 24);
      final baseline = planner.plan(
        profile: profile,
        targets: const MacroTargets(
          calories: 2500,
          proteinG: 150,
          carbsG: 300,
          fatG: 70,
        ),
        isTrainingDay: false,
        planningDate: date,
      );

      final recentLogs = baseline
          .map(
            (meal) => NutritionLog(
              id: 'recent_${meal.id}',
              userId: profile.userId,
              name: meal.name,
              source: NutritionLogSource.template,
              mealType: meal.type,
              macros: meal.macros,
              loggedAt: date.subtract(const Duration(days: 1)),
              templateId: meal.id.replaceFirst('_${meal.type.value}', ''),
              planMealId: meal.id,
            ),
          )
          .toList();

      final rotated = planner.plan(
        profile: profile,
        targets: const MacroTargets(
          calories: 2500,
          proteinG: 150,
          carbsG: 300,
          fatG: 70,
        ),
        isTrainingDay: false,
        planningDate: date,
        recentLogs: recentLogs,
      );

      final recentlyUsedNames = recentLogs.map((log) => log.name).toSet();
      final repeatedCount = rotated
          .where((meal) => recentlyUsedNames.contains(meal.name))
          .length;

      expect(repeatedCount, lessThan(baseline.length));
    });
  });
}
