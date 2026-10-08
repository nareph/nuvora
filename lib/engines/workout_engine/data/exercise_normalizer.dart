import 'package:gymgenius/engines/workout_engine/data/models/exercise_dataset_record.dart';
import 'package:gymgenius/engines/workout_engine/data/models/exercise_taxonomy_record.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';

/// Merges a dataset record + a taxonomy record into a single
/// [ExercisePoolEntry] used by the Workout Engine.
class ExerciseNormalizer {
  ExerciseNormalizer._();

  static ExercisePoolEntry normalize({
    required ExerciseDatasetRecord dataset,
    required ExerciseTaxonomyRecord taxonomy,
  }) {
    final instructions = _resolveInstructions(dataset.instructions);

    return ExercisePoolEntry(
      id: dataset.id,
      name: dataset.name,
      category: taxonomy.category,
      difficulty: taxonomy.difficulty,
      equipmentType: taxonomy.equipment,
      targetMuscles: taxonomy.primaryMuscles,
      secondaryMuscles: taxonomy.secondaryMuscles,
      compatibleSplits: taxonomy.compatibleSplits.toSet(),
      usesWeight: !taxonomy.isBodyweight,
      isTimed: taxonomy.isTimed,
      movementPattern: taxonomy.movementPattern,
      mechanics: taxonomy.mechanics,
      forceType: taxonomy.forceType,
      laterality: taxonomy.laterality,
      planeOfMotion: taxonomy.planeOfMotion,
      description: instructions['en'] ?? '',
      instructions: instructions,
      gifUrl: 'assets/exercises/${dataset.gifUrl}',
      imageUrl: 'assets/exercises/${dataset.image}',
      mediaAttribution: dataset.attribution,
    );
  }

  /// Keeps only the English instructions and drops the rest.
  ///
  /// The upstream dataset ships instructions in 10 languages, but the app
  /// currently displays English only. Filtering here (rather than downstream)
  /// keeps the pool entries lean and prevents accidental fallback to a
  /// non-English string somewhere in the UI.
  static Map<String, String> _resolveInstructions(Map<String, String> raw) {
    final en = raw['en'];
    if (en == null || en.isEmpty) return const {};
    return Map<String, String>.unmodifiable({'en': en});
  }
}
