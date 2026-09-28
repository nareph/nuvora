import 'package:flutter_test/flutter_test.dart';
import 'package:gymgenius/domain/enums/nutrition_data_quality.dart';
import 'package:gymgenius/domain/enums/nutrition_log_source.dart';

void main() {
  group('NutritionDataQuality', () {
    test('serializes enum values', () {
      expect(
        NutritionDataQuality.standardized.value,
        'standardized',
      );
      expect(
        NutritionDataQuality.estimated.value,
        'estimated',
      );
      expect(
        NutritionDataQuality.manual.value,
        'manual',
      );
    });

    test('parses enum values', () {
      expect(
        NutritionDataQualityExtension.fromValue('standardized'),
        NutritionDataQuality.standardized,
      );

      expect(
        NutritionDataQualityExtension.fromValue('estimated'),
        NutritionDataQuality.estimated,
      );

      expect(
        NutritionDataQualityExtension.fromValue('manual'),
        NutritionDataQuality.manual,
      );
    });

    test('falls back to estimated for unknown values', () {
      expect(
        NutritionDataQualityExtension.fromValue('unknown'),
        NutritionDataQuality.estimated,
      );
    });

    test('maps nutrition log sources to default data quality', () {
      expect(
        NutritionDataQualityExtension.fromSource(
          NutritionLogSource.template,
        ),
        NutritionDataQuality.standardized,
      );

      expect(
        NutritionDataQualityExtension.fromSource(
          NutritionLogSource.database,
        ),
        NutritionDataQuality.standardized,
      );

      expect(
        NutritionDataQualityExtension.fromSource(
          NutritionLogSource.composed,
        ),
        NutritionDataQuality.estimated,
      );

      expect(
        NutritionDataQualityExtension.fromSource(
          NutritionLogSource.manual,
        ),
        NutritionDataQuality.manual,
      );
    });
  });
}
