import 'package:gymgenius/data/datasources/local/hive/models/logged_food_portion_hive_model.dart';
import 'package:gymgenius/data/datasources/local/hive/models/meal_hive_model.dart';
import 'package:gymgenius/data/datasources/local/hive/models/nutrition_log_hive_model.dart';
import 'package:gymgenius/data/datasources/local/hive/models/nutrition_plan_hive_model.dart';
import 'package:gymgenius/data/datasources/local/hive/models/nutrition_profile_hive_model.dart';
import 'package:gymgenius/domain/entities/logged_food_portion.dart';
import 'package:gymgenius/domain/entities/meal.dart';
import 'package:gymgenius/domain/entities/nutrition_log.dart';
import 'package:gymgenius/domain/entities/nutrition_plan.dart';
import 'package:gymgenius/domain/entities/nutrition_profile.dart';
import 'package:gymgenius/domain/enums/meal_objective.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/enums/nutrition_data_quality.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';
import 'package:gymgenius/domain/enums/nutrition_status.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';

class NutritionMapper {
  const NutritionMapper._();

  static String planKey(String userId, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final stamp =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return '${userId}_$stamp';
  }

  static NutritionProfile toProfileDomain(NutritionProfileHiveModel model) {
    return NutritionProfile(
      userId: model.userId,
      date: model.date,
      targets: MacroTargets(
        calories: model.calories,
        proteinG: model.proteinG,
        carbsG: model.carbsG,
        fatG: model.fatG,
        waterMl: model.waterMl,
      ),
      country: model.country,
      preferredFoods: List<String>.from(model.preferredFoods),
      restrictedFoods: List<String>.from(model.restrictedFoods),
      adherenceScore: model.adherenceScore,
    );
  }

  static NutritionProfileHiveModel toProfileHive(NutritionProfile entity) {
    return NutritionProfileHiveModel(
      userId: entity.userId,
      date: entity.date,
      calories: entity.targets.calories,
      proteinG: entity.targets.proteinG,
      carbsG: entity.targets.carbsG,
      fatG: entity.targets.fatG,
      waterMl: entity.targets.waterMl,
      country: entity.country,
      preferredFoods: List<String>.from(entity.preferredFoods),
      restrictedFoods: List<String>.from(entity.restrictedFoods),
      adherenceScore: entity.adherenceScore,
    );
  }

  static NutritionPlan toPlanDomain(NutritionPlanHiveModel model) {
    return NutritionPlan(
      userId: model.userId,
      date: model.date,
      targets: MacroTargets(
        calories: model.calories,
        proteinG: model.proteinG,
        carbsG: model.carbsG,
        fatG: model.fatG,
        waterMl: model.waterMl,
      ),
      maintenanceCalories: model.maintenanceCalories,
      status: NutritionStatusExtension.fromValue(model.status),
      meals: model.meals.map(_toMealDomain).toList(),
      country: model.country,
      isTrainingDay: model.isTrainingDay,
      reasons: List<String>.from(model.reasons),
      generatedBy: model.generatedBy,
    );
  }

  static NutritionPlanHiveModel toPlanHive(NutritionPlan entity) {
    return NutritionPlanHiveModel(
      id: planKey(entity.userId, entity.date),
      userId: entity.userId,
      date: entity.date,
      calories: entity.targets.calories,
      proteinG: entity.targets.proteinG,
      carbsG: entity.targets.carbsG,
      fatG: entity.targets.fatG,
      waterMl: entity.targets.waterMl,
      maintenanceCalories: entity.maintenanceCalories,
      status: entity.status.value,
      meals: entity.meals.map(_toMealHive).toList(),
      country: entity.country,
      isTrainingDay: entity.isTrainingDay,
      reasons: List<String>.from(entity.reasons),
      generatedBy: entity.generatedBy,
    );
  }

  static Meal _toMealDomain(MealHiveModel model) {
    return Meal(
      id: model.id,
      name: model.name,
      type: MealTypeExtension.fromValue(model.type),
      objective: MealObjectiveExtension.fromValue(model.objective),
      ingredients: List<String>.from(model.ingredients),
      macros: MacroTargets(
        calories: model.calories,
        proteinG: model.proteinG,
        carbsG: model.carbsG,
        fatG: model.fatG,
      ),
      timingNote: model.timingNote,
      reason: model.reason,
    );
  }

  static MealHiveModel _toMealHive(Meal meal) {
    return MealHiveModel(
      id: meal.id,
      name: meal.name,
      type: meal.type.value,
      objective: meal.objective.value,
      ingredients: List<String>.from(meal.ingredients),
      calories: meal.macros.calories,
      proteinG: meal.macros.proteinG,
      carbsG: meal.macros.carbsG,
      fatG: meal.macros.fatG,
      timingNote: meal.timingNote,
      reason: meal.reason,
    );
  }

  static NutritionLog toLogDomain(NutritionLogHiveModel model) {
    return NutritionLog(
      id: model.id,
      userId: model.userId,
      name: model.name,
      source: NutritionLogSourceExtension.fromValue(model.source),
      mealType: MealTypeExtension.fromValue(model.mealType),
      macros: MacroTargets(
        calories: model.calories,
        proteinG: model.proteinG,
        carbsG: model.carbsG,
        fatG: model.fatG,
      ),
      loggedAt: model.loggedAt,
      templateId: model.templateId,
      planMealId: model.planMealId,
      portions: model.portions.map(_toPortionDomain).toList(),
      note: model.note,
      dataQuality: model.dataQuality == null
          ? null
          : NutritionDataQualityExtension.fromValue(
              model.dataQuality!,
            ),
    );
  }

static NutritionLogHiveModel toLogHive(NutritionLog entity) {
  return NutritionLogHiveModel(
    id: entity.id,
    userId: entity.userId,
    name: entity.name,
    source: entity.source.value,
    mealType: entity.mealType.value,
    calories: entity.macros.calories,
    proteinG: entity.macros.proteinG,
    carbsG: entity.macros.carbsG,
    fatG: entity.macros.fatG,
    loggedAt: entity.loggedAt,
    templateId: entity.templateId,
    planMealId: entity.planMealId,
    portions: entity.portions.map(_toPortionHive).toList(),
    note: entity.note,
    dataQuality: entity.dataQuality.value,
  );
}

  static LoggedFoodPortion _toPortionDomain(LoggedFoodPortionHiveModel model) {
    return LoggedFoodPortion(
      foodId: model.foodId,
      foodName: model.foodName,
      grams: model.grams,
    );
  }

  static LoggedFoodPortionHiveModel _toPortionHive(LoggedFoodPortion entity) {
    return LoggedFoodPortionHiveModel(
      foodId: entity.foodId,
      foodName: entity.foodName,
      grams: entity.grams,
    );
  }
}
