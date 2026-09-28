import 'package:flutter_test/flutter_test.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';
import 'package:gymgenius/engines/nutrition_engine/nutrition_engine.dart';

import '../engines/nutrition_engine/calorie_macro_test.dart';

void main() {
  test('sync nutrition planning accepts recent logs for meal rotation', () {
    final profile = buildTestProfile();
    final engine = NutritionEngine();
    final date = DateTime(2026, 9, 24);

    final baseline = engine.computeDailyPlanSync(
      profile: profile,
      isTrainingDay: false,
      date: date,
    );

    final recentLogs = baseline.meals
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

    final rotated = engine.computeDailyPlanSync(
      profile: profile,
      isTrainingDay: false,
      date: date,
      recentLogs: recentLogs,
    );

    final recentNames = recentLogs.map((log) => log.name).toSet();
    final repeatedCount =
        rotated.meals.where((meal) => recentNames.contains(meal.name)).length;

    expect(repeatedCount, lessThan(baseline.meals.length));
    expect(
      rotated.reasons.any(
        (reason) => reason.contains('Recent nutrition history'),
      ),
      isTrue,
    );
  });

  test('empty history keeps synchronous planning behavior valid', () {
    final profile = buildTestProfile();
    final engine = NutritionEngine();

    final plan = engine.computeDailyPlanSync(
      profile: profile,
      isTrainingDay: true,
      date: DateTime(2026, 9, 24),
      recentLogs: const [],
    );

    expect(plan.meals, isNotEmpty);
    expect(plan.targets.calories, greaterThan(0));
    expect(plan.targets.proteinG, greaterThan(0));
    expect(plan.targets.carbsG, greaterThan(0));
    expect(plan.targets.fatG, greaterThan(0));
  });
}
