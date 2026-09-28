import 'nutrition_log_source.dart';

/// Describes the confidence/quality level of nutrition data.
///
/// This does not change the nutritional values themselves.
/// It tells the application how those values were obtained.
enum NutritionDataQuality {
  /// Nutrition values come from a known standardized food or meal template.
  standardized,

  /// Nutrition values were estimated from composed foods/portions.
  estimated,

  /// Nutrition values were explicitly supplied by the user.
  manual,
}

extension NutritionDataQualityExtension on NutritionDataQuality {
  String get value {
    switch (this) {
      case NutritionDataQuality.standardized:
        return 'standardized';
      case NutritionDataQuality.estimated:
        return 'estimated';
      case NutritionDataQuality.manual:
        return 'manual';
    }
  }

  String get displayName {
    switch (this) {
      case NutritionDataQuality.standardized:
        return 'Standardized';
      case NutritionDataQuality.estimated:
        return 'Estimated';
      case NutritionDataQuality.manual:
        return 'Manual';
    }
  }

  static NutritionDataQuality fromValue(String value) {
    return NutritionDataQuality.values.firstWhere(
      (quality) => quality.value == value,
      orElse: () => NutritionDataQuality.estimated,
    );
  }

  /// Derives the default data quality from the current logging source.
  ///
  /// This preserves backward compatibility for existing callers that do not
  /// explicitly provide a quality level.
  static NutritionDataQuality fromSource(
    NutritionLogSource source,
  ) {
    switch (source) {
      case NutritionLogSource.template:
      case NutritionLogSource.database:
        return NutritionDataQuality.standardized;

      case NutritionLogSource.composed:
        return NutritionDataQuality.estimated;

      case NutritionLogSource.manual:
        return NutritionDataQuality.manual;
    }
  }
}
