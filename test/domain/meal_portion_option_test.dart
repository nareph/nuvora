import 'package:flutter_test/flutter_test.dart';
import 'package:gymgenius/domain/entities/meal_portion_option.dart';

void main() {
  group('MealPortionOption', () {
    test('scales a reference portion to normalized grams', () {
      const option = MealPortionOption(
        id: 'large',
        label: 'Large portion',
        multiplier: 1.25,
      );

      expect(option.gramsFrom(200), 250);
    });

    test('copyWith preserves values that are not overridden', () {
      const option = MealPortionOption(
        id: 'standard',
        label: 'Standard portion',
        multiplier: 1.0,
      );

      final updated = option.copyWith(multiplier: 0.75);

      expect(updated.id, 'standard');
      expect(updated.label, 'Standard portion');
      expect(updated.multiplier, 0.75);
    });

    test('value equality compares all fields', () {
      const first = MealPortionOption(
        id: 'standard',
        label: 'Standard portion',
        multiplier: 1.0,
      );
      const second = MealPortionOption(
        id: 'standard',
        label: 'Standard portion',
        multiplier: 1.0,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
