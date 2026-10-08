import 'package:gymgenius/domain/enums/exports.dart';

class ExerciseTaxonomyRecord {
  final EquipmentType equipment;
  final ExerciseCategory category;
  final MovementPattern movementPattern;
  final ExerciseDifficulty difficulty;
  final Mechanics mechanics;
  final ForceType forceType;
  final Laterality laterality;
  final PlaneOfMotion planeOfMotion;
  final bool isBodyweight;
  final bool isTimed;
  final List<MuscleGroup> primaryMuscles;
  final List<MuscleGroup> secondaryMuscles;
  final List<String> compatibleSplits;
  final int defaultSets;
  final String defaultReps;
  final int defaultRestSeconds;

  const ExerciseTaxonomyRecord({
    required this.equipment,
    required this.category,
    required this.movementPattern,
    required this.difficulty,
    required this.mechanics,
    required this.forceType,
    required this.laterality,
    required this.planeOfMotion,
    required this.isBodyweight,
    required this.isTimed,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.compatibleSplits,
    required this.defaultSets,
    required this.defaultReps,
    required this.defaultRestSeconds,
  });

  factory ExerciseTaxonomyRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseTaxonomyRecord(
      equipment: _enumByName(
        EquipmentType.values,
        json['equipment'] as String?,
        EquipmentType.bodyweight,
      ),
      category: _enumByName(
        ExerciseCategory.values,
        json['category'] as String?,
        ExerciseCategory.compound,
      ),
      movementPattern: _enumByName(
        MovementPattern.values,
        json['movementPattern'] as String?,
        MovementPattern.push,
      ),
      difficulty: _enumByName(
        ExerciseDifficulty.values,
        json['difficulty'] as String?,
        ExerciseDifficulty.beginner,
      ),
      mechanics: _enumByName(
        Mechanics.values,
        json['mechanics'] as String?,
        Mechanics.openChain,
      ),
      forceType: _enumByName(
        ForceType.values,
        json['forceType'] as String?,
        ForceType.push,
      ),
      laterality: _enumByName(
        Laterality.values,
        json['laterality'] as String?,
        Laterality.bilateral,
      ),
      planeOfMotion: _enumByName(
        PlaneOfMotion.values,
        json['planeOfMotion'] as String?,
        PlaneOfMotion.sagittal,
      ),
      isBodyweight: json['isBodyweight'] as bool? ?? false,
      isTimed: json['isTimed'] as bool? ?? false,
      primaryMuscles: _muscles(json['primaryMuscles']),
      secondaryMuscles: _muscles(json['secondaryMuscles']),
      compatibleSplits: List<String>.from(
        json['compatibleSplits'] as List? ?? const [],
      ),
      defaultSets: json['defaultSets'] as int? ?? 3,
      defaultReps: json['defaultReps'] as String? ?? '8-12',
      defaultRestSeconds: json['defaultRestSeconds'] as int? ?? 60,
    );
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    if (name == null) return fallback;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  static List<MuscleGroup> _muscles(dynamic raw) {
    if (raw is! List) return const [];
    final result = <MuscleGroup>[];
    for (final item in raw) {
      if (item is! String) continue;
      for (final m in MuscleGroup.values) {
        if (m.name == item) {
          result.add(m);
          break;
        }
      }
    }
    return List.unmodifiable(result);
  }
}
