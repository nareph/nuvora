/// A human-friendly portion option for a meal or food item.
///
/// The UI exposes [label] while the nutrition layer uses [multiplier]
/// to convert a reference portion into normalized grams.
///
/// Example:
///   Small portion   -> 0.75
///   Standard portion -> 1.00
///   Large portion   -> 1.25
class MealPortionOption {
  final String id;
  final String label;
  final double multiplier;

  const MealPortionOption({
    required this.id,
    required this.label,
    required this.multiplier,
  })  : assert(id != '', 'Portion option id cannot be empty.'),
        assert(label != '', 'Portion option label cannot be empty.'),
        assert(multiplier > 0, 'Portion multiplier must be greater than zero.');

  /// Converts a reference portion expressed in grams to this portion size.
  double gramsFrom(double referenceGrams) {
    assert(referenceGrams >= 0, 'Reference grams cannot be negative.');
    return referenceGrams * multiplier;
  }

  MealPortionOption copyWith({
    String? id,
    String? label,
    double? multiplier,
  }) {
    return MealPortionOption(
      id: id ?? this.id,
      label: label ?? this.label,
      multiplier: multiplier ?? this.multiplier,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MealPortionOption &&
        other.id == id &&
        other.label == label &&
        other.multiplier == multiplier;
  }

  @override
  int get hashCode => Object.hash(id, label, multiplier);
}
