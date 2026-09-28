import 'package:gymgenius/domain/entities/logged_food_portion.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/enums/nutrition_data_quality.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';

/// A single logged meal or snack entry for macro tracking.
class NutritionLog {
  final String id;
  final String userId;
  final String name;
  final NutritionLogSource source;
  final MealType mealType;
  final MacroTargets macros;
  final DateTime loggedAt;
  final String? templateId;
  final String? planMealId;
  final List<LoggedFoodPortion> portions;
  final String? note;

  /// Describes how trustworthy/precise the recorded nutrition values are.
  ///
  /// When omitted, the value is derived from [source], preserving
  /// backward compatibility with all existing callers.
  final NutritionDataQuality dataQuality;

  NutritionLog({
    required this.id,
    required this.userId,
    required this.name,
    required this.source,
    required this.mealType,
    required this.macros,
    required this.loggedAt,
    this.templateId,
    this.planMealId,
    this.portions = const [],
    this.note,
    NutritionDataQuality? dataQuality,
  }) : dataQuality =
            dataQuality ?? NutritionDataQualityExtension.fromSource(source);

  DateTime get dayKey => DateTime(
        loggedAt.year,
        loggedAt.month,
        loggedAt.day,
      );

  bool get isValid =>
      userId.isNotEmpty &&
      name.trim().isNotEmpty &&
      macros.calories > 0 &&
      (source != NutritionLogSource.composed || portions.any((p) => p.isValid));

  /// Whether the logged nutrition should be displayed as approximate.
  bool get isEstimated => dataQuality == NutritionDataQuality.estimated;

  /// Whether the values come from standardized knowledge-base data.
  bool get isStandardized => dataQuality == NutritionDataQuality.standardized;

  /// Whether the values were explicitly entered by the user.
  bool get isManual => dataQuality == NutritionDataQuality.manual;

  @override
  String toString() => 'NutritionLog('
      '$name, '
      '${source.value}, '
      '${dataQuality.value}, '
      '${macros.calories} kcal'
      ')';
}
