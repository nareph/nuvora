// lib/engines/workout_engine/builders/mapper/exercise_mapper.dart

import 'package:gymgenius/domain/entities/exercise.dart';
import 'package:gymgenius/domain/enums/exercise_difficulty.dart';
import 'package:gymgenius/domain/value_objects/tempo.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';

class ExerciseMapper {
  ExerciseMapper._();

  static Exercise toDomain({
    required ExercisePoolEntry entry,
    required int sets,
    required String reps,
    required int restSeconds,
    required ExerciseDifficulty difficulty,
    required Tempo tempo,
    required String description,
    // computed by WeightSuggestionResolver upstream.
    String? weightSuggestion,
  }) {
    return Exercise(
      id: entry.id,
      name: entry.name,
      description: description,
      category: entry.category,
      movementPattern: entry.movementPattern,
      primaryMuscles: entry.targetMuscles,
      secondaryMuscles: entry.secondaryMuscles,
      equipment: entry.equipmentType,
      difficulty: difficulty,
      mechanics: entry.mechanics,
      forceType: entry.forceType,
      laterality: entry.laterality,
      planeOfMotion: entry.planeOfMotion,
      sets: sets,
      reps: reps,
      restSeconds: restSeconds,
      weightSuggestion: weightSuggestion,
      isBodyweight: !entry.usesWeight,
      isTimed: entry.isTimed,
      targetDurationSeconds: entry.isTimed ? 30 : null,
      instructions: description,
      tips: const [
        'Maintain proper technique throughout the movement.',
        'Control the eccentric phase.',
        'Breathe consistently during each repetition.',
      ],
      commonMistakes: const [
        'Using excessive momentum.',
        'Reducing the range of motion.',
        'Losing core stability.',
      ],
      rpe: null,
      rir: null,
      tempo: tempo,
    );
  }
}
