import 'package:gymgenius/domain/entities/food_item.dart';
import 'package:gymgenius/domain/entities/logged_food_portion.dart';
import 'package:gymgenius/domain/entities/meal.dart';
import 'package:gymgenius/domain/enums/food_category.dart';
import 'package:gymgenius/domain/enums/meal_objective.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/builders/meal_log_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = MealLogBuilder();

  final rice = FoodItem(
    id: 'cm_rice',
    name: 'White rice (cooked)',
    country: 'Cameroon',
    category: FoodCategory.carbohydrate,
    caloriesPer100g: 130,
    proteinGPer100g: 2.7,
    carbsGPer100g: 28,
    fatGPer100g: 0.3,
    defaultPortionLabel: '1 cup',
    defaultPortionGrams: 158,
  );

  final eggs = FoodItem(
    id: 'cm_eggs',
    name: 'Eggs',
    country: 'Cameroon',
    category: FoodCategory.protein,
    caloriesPer100g: 155,
    proteinGPer100g: 13,
    carbsGPer100g: 1.1,
    fatGPer100g: 11,
    defaultPortionLabel: '2 eggs',
    defaultPortionGrams: 100,
  );

  group('MealLogBuilder', () {
    test('tier 1 logs suggested plan meal with template id', () {
      const meal = Meal(
        id: 'cm_meal_rice_chicken_lunch',
        name: 'Rice and grilled chicken',
        type: MealType.lunch,
        objective: MealObjective.highProtein,
        ingredients: ['Rice', 'Chicken'],
        macros: MacroTargets(
          calories: 620,
          proteinG: 45,
          carbsG: 60,
          fatG: 12,
        ),
      );

      final log = builder.fromPlanMeal(meal: meal, userId: 'user1');

      expect(log.source.name, 'template');
      expect(log.planMealId, meal.id);
      expect(log.templateId, 'cm_meal_rice_chicken');
      expect(log.macros.calories, 620);
    });

    test('tier 2 computes macros from food portions', () {
      final log = builder.fromFoodPortions(
        userId: 'user1',
        name: 'Rice and eggs breakfast',
        mealType: MealType.breakfast,
        portions: const [
          LoggedFoodPortion(
            foodId: 'cm_rice',
            foodName: 'White rice (cooked)',
            grams: 158,
          ),
          LoggedFoodPortion(
            foodId: 'cm_eggs',
            foodName: 'Eggs',
            grams: 100,
          ),
        ],
        availableFoods: [rice, eggs],
      );

      expect(log.source.name, 'composed');
      expect(log.portions.length, 2);
      expect(log.macros.calories, greaterThan(300));
      expect(log.macros.proteinG, greaterThan(10));
    });

    test('tier 3 stores manual macros as entered', () {
      final log = builder.fromManual(
        userId: 'user1',
        name: 'Street food snack',
        mealType: MealType.snack,
        macros: const MacroTargets(
          calories: 450,
          proteinG: 12,
          carbsG: 55,
          fatG: 18,
        ),
      );

      expect(log.source.name, 'manual');
      expect(log.name, 'Street food snack');
      expect(log.macros.calories, 450);
      expect(log.portions, isEmpty);
    });

    test('sumLoggedMacros aggregates a day of logs', () {
      final total = builder.sumLoggedMacros([
        builder.fromManual(
          userId: 'user1',
          name: 'A',
          mealType: MealType.breakfast,
          macros: const MacroTargets(
            calories: 400,
            proteinG: 20,
            carbsG: 40,
            fatG: 10,
          ),
        ),
        builder.fromManual(
          userId: 'user1',
          name: 'B',
          mealType: MealType.lunch,
          macros: const MacroTargets(
            calories: 600,
            proteinG: 30,
            carbsG: 60,
            fatG: 15,
          ),
        ),
      ]);

      expect(total.calories, 1000);
      expect(total.proteinG, 50);
      expect(total.carbsG, 100);
      expect(total.fatG, 25);
    });
  });
}
