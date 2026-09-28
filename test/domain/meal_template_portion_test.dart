import 'package:flutter_test/flutter_test.dart';
import 'package:gymgenius/domain/entities/meal_portion_option.dart';
import 'package:gymgenius/domain/enums/meal_objective.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/models/meal_template.dart';

void main() {
  group('MealTemplate portions', () {
    late MealTemplate meal;

    setUp(() {
      meal = MealTemplate(
        id: 'test_meal',
        name: 'Test meal',
        objective: MealObjective.highProtein,
        ingredientIds: const ['food_1'],
        ingredientNames: const ['Food 1'],
        baseMacros: const MacroTargets(
          calories: 600,
          proteinG: 30,
          carbsG: 60,
          fatG: 20,
        ),
      );
    });

    test('provides default human-friendly portion options', () {
      expect(meal.effectivePortionOptions.map((p) => p.id), [
        'small',
        'standard',
        'large',
      ]);

      expect(
        meal.effectivePortionOptions.map((p) => p.multiplier),
        [0.75, 1.0, 1.25],
      );
    });

    test('uses explicit options when a template defines them', () {
      const explicit = [
        MealPortionOption(
          id: 'plate',
          label: '1 plate',
          multiplier: 1.0,
        ),
        MealPortionOption(
          id: 'half_plate',
          label: 'Half plate',
          multiplier: 0.5,
        ),
      ];

      final custom = meal.copyWith(portionOptions: explicit);

      expect(custom.effectivePortionOptions, explicit);
    });

    test('scales reference macros using the selected portion', () {
      const large = MealPortionOption(
        id: 'large',
        label: 'Large portion',
        multiplier: 1.25,
      );

      final scaled = meal.macrosForPortion(large);

      expect(scaled.calories, 750);
      expect(scaled.proteinG, 38);
      expect(scaled.carbsG, 75);
      expect(scaled.fatG, 25);
    });

    test('standard portion preserves reference macros', () {
      const standard = MealPortionOption(
        id: 'standard',
        label: 'Standard portion',
        multiplier: 1.0,
      );

      final scaled = meal.macrosForPortion(standard);

      expect(scaled.calories, meal.baseMacros.calories);
      expect(scaled.proteinG, meal.baseMacros.proteinG);
      expect(scaled.carbsG, meal.baseMacros.carbsG);
      expect(scaled.fatG, meal.baseMacros.fatG);
    });
  });
}
