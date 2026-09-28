import 'package:flutter_test/flutter_test.dart';

import 'package:gymgenius/domain/entities/logged_food_portion.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/entities/meal_portion_option.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/enums/meal_objective.dart';
import 'package:gymgenius/domain/enums/nutrition_data_quality.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/builders/meal_log_builder.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/countries/cameroon/cameroon_dataset.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/models/meal_template.dart';
import 'package:gymgenius/engines/nutrition_engine/nutrition_engine.dart';

import 'calorie_macro_test.dart';

MealTemplate templateForTest() => const MealTemplate(
      id: 'test_meal',
      name: 'Test meal',
      objective: MealObjective.highProtein,
      ingredientIds: ['food_a'],
      ingredientNames: ['Food A'],
      baseMacros: MacroTargets(
        calories: 500,
        proteinG: 30,
        carbsG: 50,
        fatG: 15,
      ),
    );

void main() {
  const builder = MealLogBuilder();

  group('MealLogBuilder', () {
    test('plan meal is standardized', () {
      final profile = buildTestProfile();
      final engine = NutritionEngine();

      final plan = engine.computeDailyPlanSync(
        profile: profile,
        isTrainingDay: false,
        date: DateTime(2026, 9, 24),
      );

      final meal = plan.meals.first;

      final log = builder.fromPlanMeal(
        meal: meal,
        userId: profile.userId,
        loggedAt: DateTime(2026, 9, 24, 8),
      );

      expect(log, isA<NutritionLog>());
      expect(log.source, NutritionLogSource.template);
      expect(log.dataQuality, NutritionDataQuality.standardized);
      expect(log.userId, profile.userId);
      expect(log.name, meal.name);
      expect(log.mealType, meal.type);
      expect(log.planMealId, meal.id);
      expect(log.templateId, isNotNull);
      expect(log.macros, meal.macros);
    });

    test('database meal keeps base macros when no portion is supplied', () {
      final log = builder.fromMealTemplate(
        template: templateForTest(),
        mealType: MealType.lunch,
        userId: 'user-1',
      );

      expect(log.source, NutritionLogSource.database);
      expect(log.dataQuality, NutritionDataQuality.standardized);
      expect(log.templateId, 'test_meal');
      expect(log.macros.calories, 500);
      expect(log.macros.proteinG, 30);
      expect(log.macros.carbsG, 50);
      expect(log.macros.fatG, 15);
    });

    test('database meal scales macros when a portion is supplied', () {
      const large = MealPortionOption(
        id: 'large',
        label: 'Large',
        multiplier: 1.25,
      );

      final log = builder.fromMealTemplate(
        template: templateForTest(),
        mealType: MealType.dinner,
        userId: 'user-1',
        portion: large,
      );

      expect(log.source, NutritionLogSource.database);
      expect(log.dataQuality, NutritionDataQuality.standardized);
      expect(log.templateId, 'test_meal');
      expect(log.mealType, MealType.dinner);
      expect(log.macros.calories, 625);
      expect(log.macros.proteinG, 38);
      expect(log.macros.carbsG, 63);
      expect(log.macros.fatG, 19);
    });

    test('composed meal is estimated and calculates macros from portions', () {
      const dataset = CameroonFoodDataset();

      final foods = dataset.foods;

      final eggs = foods.firstWhere((food) => food.id == 'cm_eggs');
      final bread = foods.firstWhere((food) => food.id == 'cm_bread');

      const portions = [
        LoggedFoodPortion(
          foodId: 'cm_eggs',
          foodName: 'Eggs',
          grams: 100,
        ),
        LoggedFoodPortion(
          foodId: 'cm_bread',
          foodName: 'Local bread',
          grams: 70,
        ),
      ];

      final log = builder.fromFoodPortions(
        userId: 'user-1',
        name: 'Eggs + bread',
        mealType: MealType.breakfast,
        portions: portions,
        availableFoods: foods,
      );

      expect(log.source, NutritionLogSource.composed);
      expect(log.dataQuality, NutritionDataQuality.estimated);
      expect(log.name, 'Eggs + bread');
      expect(log.mealType, MealType.breakfast);
      expect(log.portions.length, 2);

      expect(log.macros.calories, 341);
      expect(log.macros.proteinG, 19);
      expect(log.macros.carbsG, 35);
      expect(log.macros.fatG, 13);

      expect(eggs.id, 'cm_eggs');
      expect(bread.id, 'cm_bread');
    });

    test('manual meal is explicitly manual', () {
      const macros = MacroTargets(
        calories: 700,
        proteinG: 35,
        carbsG: 80,
        fatG: 25,
      );

      final log = builder.fromManual(
        userId: 'user-1',
        name: 'Manual meal',
        mealType: MealType.dinner,
        macros: macros,
      );

      expect(log.source, NutritionLogSource.manual);
      expect(log.dataQuality, NutritionDataQuality.manual);
      expect(log.mealType, MealType.dinner);
      expect(log.macros, macros);
      expect(log.name, 'Manual meal');
    });

    test('empty names receive safe fallback names', () {
      const macros = MacroTargets(
        calories: 400,
        proteinG: 20,
        carbsG: 40,
        fatG: 10,
      );

      final manualLog = builder.fromManual(
        userId: 'user-1',
        name: '   ',
        mealType: MealType.snack,
        macros: macros,
      );

      expect(manualLog.name, 'Manual meal');
      expect(manualLog.dataQuality, NutritionDataQuality.manual);

      final composedLog = builder.fromFoodPortions(
        userId: 'user-1',
        name: '   ',
        mealType: MealType.snack,
        portions: const [],
        availableFoods: const [],
      );

      expect(composedLog.name, 'Custom meal');
      expect(composedLog.dataQuality, NutritionDataQuality.estimated);
    });

    test('sumLoggedMacros aggregates all logs', () {
      final standardized = NutritionLog(
        id: 'standardized',
        userId: 'user-1',
        name: 'Known meal',
        source: NutritionLogSource.database,
        mealType: MealType.breakfast,
        macros: const MacroTargets(
          calories: 500,
          proteinG: 30,
          carbsG: 50,
          fatG: 15,
        ),
        loggedAt: DateTime(2026, 9, 24, 8),
      );

      final estimated = NutritionLog(
        id: 'estimated',
        userId: 'user-1',
        name: 'Composed meal',
        source: NutritionLogSource.composed,
        mealType: MealType.lunch,
        macros: const MacroTargets(
          calories: 350,
          proteinG: 20,
          carbsG: 40,
          fatG: 10,
        ),
        loggedAt: DateTime(2026, 9, 24, 13),
      );

      final total = builder.sumLoggedMacros([
        standardized,
        estimated,
      ]);

      expect(total.calories, 850);
      expect(total.proteinG, 50);
      expect(total.carbsG, 90);
      expect(total.fatG, 25);
    });
  });
}
