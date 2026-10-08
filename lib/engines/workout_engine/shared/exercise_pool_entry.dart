import '../../../domain/enums/exports.dart';

class ExercisePoolEntry {
  /// Unique identifier.
  final String id;

  /// Exercise name.
  final String name;

  /// Compound / Isolation / Cardio / Mobility.
  final ExerciseCategory category;

  /// Beginner / Intermediate / Advanced.
  final ExerciseDifficulty difficulty;

  /// Primary required equipment.
  final EquipmentType equipmentType;

  /// Additional equipment required in addition to [equipmentType].
  final List<EquipmentType> additionalEquipment;

  /// Main muscles.
  final List<MuscleGroup> targetMuscles;

  /// Secondary muscles.
  final List<MuscleGroup> secondaryMuscles;

  /// Splits in which this exercise can be used.
  final Set<String> compatibleSplits;

  /// Suggested weight.
  final String? weightSuggestion;

  /// Uses external weight.
  final bool usesWeight;

  /// Timed exercise.
  final bool isTimed;

  /// Movement information.
  final MovementPattern movementPattern;
  final Mechanics mechanics;
  final ForceType forceType;
  final Laterality laterality;
  final PlaneOfMotion planeOfMotion;

  /// Short description (usually the FR instructions).
  final String description;

  // ───────────────────────────────────────────────────────────
  // NEW FIELDS (Phase 2 — dataset integration)
  // ───────────────────────────────────────────────────────────

  /// Localized instructions: {"en": "...", "fr": "..."}.
  final Map<String, String> instructions;

  /// Absolute asset path to the animated GIF (nullable).
  final String? gifUrl;

  /// Absolute asset path to the thumbnail (nullable).
  final String? imageUrl;

  /// Required attribution for the media (Gym visual).
  final String? mediaAttribution;

  /// Convenience accessor: comma-separated list of primary muscles.
  String get primaryMusclesDisplay =>
      targetMuscles.map((m) => m.displayName).join(', ');

  const ExercisePoolEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.equipmentType,
    this.additionalEquipment = const [],
    required this.targetMuscles,
    this.secondaryMuscles = const [],
    this.compatibleSplits = const {},
    this.weightSuggestion,
    this.usesWeight = false,
    this.isTimed = false,
    required this.movementPattern,
    required this.mechanics,
    required this.forceType,
    required this.laterality,
    required this.planeOfMotion,
    required this.description,
    this.instructions = const {},
    this.gifUrl,
    this.imageUrl,
    this.mediaAttribution,
  });

  bool get isCompound => category == ExerciseCategory.compound;
  bool get isIsolation => category == ExerciseCategory.isolation;

  bool isCompatibleWithSplit(String splitName) {
    return compatibleSplits.contains(splitName);
  }

  /// Returns the full set of equipment required by this exercise.
  Set<EquipmentType> get allRequiredEquipment => {
        equipmentType,
        ...additionalEquipment,
      };

  /// Convenience accessor: preferred language with English fallback.
  String instructionsFor(String languageCode) {
    return instructions[languageCode] ?? instructions['en'] ?? description;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': category.name,
      'difficulty': difficulty.name,
      'equipmentType': equipmentType.name,
      if (additionalEquipment.isNotEmpty)
        'additionalEquipment': additionalEquipment.map((e) => e.name).toList(),
      'targetMuscles': targetMuscles.map((e) => e.name).toList(),
      'secondaryMuscles': secondaryMuscles.map((e) => e.name).toList(),
      'compatibleSplits': compatibleSplits.toList(),
      if (weightSuggestion != null) 'weightSuggestion': weightSuggestion,
      'usesWeight': usesWeight,
      'isTimed': isTimed,
      'movementPattern': movementPattern.name,
      'mechanics': mechanics.name,
      'forceType': forceType.name,
      'laterality': laterality.name,
      'planeOfMotion': planeOfMotion.name,
      'description': description,
      if (instructions.isNotEmpty) 'instructions': instructions,
      if (gifUrl != null) 'gifUrl': gifUrl,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (mediaAttribution != null) 'mediaAttribution': mediaAttribution,
    };
  }
}
