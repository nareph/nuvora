import 'dart:io';

import 'package:gymgenius/data/datasources/local/hive/boxes/hive_boxes.dart';
import 'package:gymgenius/data/datasources/local/hive/models/logged_food_portion_hive_model.dart';
import 'package:gymgenius/data/datasources/local/hive/models/nutrition_log_hive_model.dart';
import 'package:gymgenius/data/mappers/nutrition_mapper.dart';
import 'package:gymgenius/data/repositories/nutrition_repository_impl.dart';
import 'package:gymgenius/domain/entities/logged_food_portion.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/enums/nutrition_data_quality.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('nutrition logs persist and filter by day', () async {
    final tmpDir = await Directory.systemTemp.createTemp(
      'gymgenius_nutrition_logs_test_',
    );

    Hive.init(tmpDir.path);
    Hive.registerAdapter(LoggedFoodPortionHiveModelAdapter());
    Hive.registerAdapter(NutritionLogHiveModelAdapter());
    await Hive.openBox<NutritionLogHiveModel>(HiveBoxes.nutritionLogs);

    const repo = NutritionRepositoryImpl();
    const userId = 'user_logs';

    final today = DateTime(2026, 8, 17, 13, 30);
    final yesterday = DateTime(2026, 8, 16, 13, 30);

    await repo.saveNutritionLog(
      NutritionLog(
        id: 'log_today',
        userId: userId,
        name: 'Rice and eggs',
        source: NutritionLogSource.composed,
        mealType: MealType.lunch,
        macros: const MacroTargets(
          calories: 520,
          proteinG: 25,
          carbsG: 60,
          fatG: 12,
        ),
        loggedAt: today,
        portions: const [
          LoggedFoodPortion(
            foodId: 'cm_rice',
            foodName: 'Rice',
            grams: 150,
          ),
        ],
      ),
    );

    await repo.saveNutritionLog(
      NutritionLog(
        id: 'log_yesterday',
        userId: userId,
        name: 'Manual snack',
        source: NutritionLogSource.manual,
        mealType: MealType.snack,
        macros: const MacroTargets(
          calories: 300,
          proteinG: 10,
          carbsG: 30,
          fatG: 8,
        ),
        loggedAt: yesterday,
      ),
    );

    final todayLogs = await repo.getNutritionLogsForDay(userId, today);
    expect(todayLogs.length, 1);
    expect(todayLogs.first.name, 'Rice and eggs');
    expect(todayLogs.first.portions.first.foodId, 'cm_rice');

    final history = await repo.getNutritionLogHistory(userId);
    expect(history.length, 2);

    await repo.deleteNutritionLog('log_today');
    final afterDelete = await repo.getNutritionLogsForDay(userId, today);
    expect(afterDelete, isEmpty);

    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  test('derives data quality for legacy logs without field 14', () {
    final legacyModel = NutritionLogHiveModel(
      id: 'legacy',
      userId: 'user_legacy',
      name: 'Rice and eggs',
      source: NutritionLogSource.composed.value,
      mealType: MealType.lunch.value,
      calories: 520,
      proteinG: 25,
      carbsG: 60,
      fatG: 12,
      loggedAt: DateTime(2026, 8, 17, 13, 30),
      portions: const [],
      dataQuality: null,
    );

    final domain = NutritionMapper.toLogDomain(legacyModel);

    expect(
      domain.dataQuality,
      NutritionDataQuality.estimated,
    );
  });
}
