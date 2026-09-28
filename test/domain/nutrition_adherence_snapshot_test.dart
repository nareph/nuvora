import 'package:flutter_test/flutter_test.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/nutrition_engine.dart';

import '../engines/nutrition_engine/calorie_macro_test.dart';

void main() {
  group('NutritionAdherenceSnapshot', () {
    test('reports plan targets with no observed intake', () {
      final profile = buildTestProfile();
      final engine = NutritionEngine();
      final date = DateTime(2026, 9, 24);
      final plan = engine.computeDailyPlanSync(
        profile: profile,
        isTrainingDay: false,
        date: date,
      );

      final snapshot = engine.buildAdherenceSnapshot(
        plan: plan,
        logs: const [],
      );

      expect(snapshot.userId, profile.userId);
      expect(snapshot.date, date);
      expect(snapshot.targetCalories, plan.targets.calories);
      expect(snapshot.targetProtein, plan.targets.proteinG);
      expect(snapshot.targetCarbs, plan.targets.carbsG);
      expect(snapshot.targetFat, plan.targets.fatG);
      expect(snapshot.expectedMeals, 4);
      expect(snapshot.loggedMeals, 0);
      expect(snapshot.mealSlotCoverage, 0);
      expect(snapshot.loggedCalories, 0);
      expect(snapshot.loggedProtein, 0);
      expect(snapshot.loggedCarbs, 0);
      expect(snapshot.loggedFat, 0);
      expect(snapshot.missingMeals, 4);
      expect(snapshot.hasObservedIntake, isFalse);
    });

    test('counts one covered slot once when several logs share it', () {
      final profile = buildTestProfile();
      final engine = NutritionEngine();
      final date = DateTime(2026, 9, 24);
      final plan = engine.computeDailyPlanSync(
        profile: profile,
        isTrainingDay: false,
        date: date,
      );

      final breakfast = plan.meals.firstWhere(
        (meal) => meal.type.name == 'breakfast',
      );
      final logs = [
        NutritionLog(
          id: 'egg',
          userId: profile.userId,
          name: 'Eggs',
          source: NutritionLogSource.composed,
          mealType: breakfast.type,
          macros: const MacroTargets(
            calories: 200,
            proteinG: 15,
            carbsG: 2,
            fatG: 12,
          ),
          loggedAt: date.add(const Duration(hours: 8)),
        ),
        NutritionLog(
          id: 'banana',
          userId: profile.userId,
          name: 'Banana',
          source: NutritionLogSource.database,
          mealType: breakfast.type,
          macros: const MacroTargets(
            calories: 100,
            proteinG: 1,
            carbsG: 23,
            fatG: 0,
          ),
          loggedAt: date.add(const Duration(hours: 8, minutes: 10)),
        ),
      ];

      final snapshot = engine.buildAdherenceSnapshot(
        plan: plan,
        logs: logs,
      );

      expect(snapshot.loggedMeals, 1);
      expect(snapshot.expectedMeals, 4);
      expect(snapshot.mealSlotCoverage, 0.25);
      expect(snapshot.loggedCalories, 300);
      expect(snapshot.loggedProtein, 16);
      expect(snapshot.loggedCarbs, 25);
      expect(snapshot.loggedFat, 12);
      expect(snapshot.missingMeals, 3);
      expect(snapshot.hasObservedIntake, isTrue);
      expect(snapshot.calorieCoverage, greaterThan(0));
    });

    test('ignores logs from another day', () {
      final profile = buildTestProfile();
      final engine = NutritionEngine();
      final date = DateTime(2026, 9, 24);
      final plan = engine.computeDailyPlanSync(
        profile: profile,
        isTrainingDay: false,
        date: date,
      );

      final yesterday = NutritionLog(
        id: 'yesterday',
        userId: profile.userId,
        name: 'Rice and chicken',
        source: NutritionLogSource.template,
        mealType: plan.meals.first.type,
        macros: const MacroTargets(
          calories: 700,
          proteinG: 40,
          carbsG: 70,
          fatG: 20,
        ),
        loggedAt: date.subtract(const Duration(days: 1)).add(
          const Duration(hours: 8),
        ),
      );

      final snapshot = engine.buildAdherenceSnapshot(
        plan: plan,
        logs: [yesterday],
      );

      expect(snapshot.loggedCalories, 0);
      expect(snapshot.loggedMeals, 0);
      expect(snapshot.mealSlotCoverage, 0);
      expect(snapshot.hasObservedIntake, isFalse);
    });

    test('exposes the same snapshot through the engine sync facade', () {
      final profile = buildTestProfile();
      final engine = NutritionEngine();
      final date = DateTime(2026, 9, 24);
      final plan = engine.computeDailyPlanSync(
        profile: profile,
        isTrainingDay: true,
        date: date,
      );

      final snapshot = engine.buildAdherenceSnapshot(
        plan: plan,
        logs: const [],
      );

      expect(snapshot.targetCalories, plan.targets.calories);
      expect(snapshot.targetProtein, plan.targets.proteinG);
      expect(snapshot.expectedMeals, plan.meals.map((m) => m.type).toSet().length);
    });
  });
}
