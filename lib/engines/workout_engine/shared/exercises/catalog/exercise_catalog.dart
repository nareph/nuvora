import 'package:gymgenius/engines/workout_engine/data/exercise_dataset_loader.dart';
import 'package:gymgenius/engines/workout_engine/data/exercise_normalizer.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';

/// Canonical exercise catalog.
///
/// **Lazy-loaded.** The catalog is loaded on first use via
/// [ensureLoaded] — NOT at app startup.
///
/// Callers must `await ExerciseCatalog.ensureLoaded()` before calling
/// [getAll], [findById], etc.
///
/// Subsequent calls to [ensureLoaded] are no-ops.
class ExerciseCatalog {
  ExerciseCatalog._();

  static List<ExercisePoolEntry>? _cachedExercises;
  static Map<String, ExercisePoolEntry>? _cachedById;
  static Future<void>? _initialization;

  /// Loads the catalog if not already loaded.
  ///
  /// Safe to call multiple times and from multiple places — only the
  /// first call performs the actual work.
  static Future<void> ensureLoaded() async {
    _initialization ??= _doInitialize();
    return _initialization!;
  }

  static Future<void> _doInitialize() async {
    if (_cachedExercises != null) return;

    await ExerciseDatasetLoader.preload();

    final dataset = ExerciseDatasetLoader.datasetSync;
    final taxonomy = ExerciseDatasetLoader.taxonomySync;

    final byId = <String, ExercisePoolEntry>{};
    final list = <ExercisePoolEntry>[];

    for (final record in dataset) {
      final meta = taxonomy[record.id];
      if (meta == null) continue;

      final entry = ExerciseNormalizer.normalize(
        dataset: record,
        taxonomy: meta,
      );

      byId[entry.id] = entry;
      list.add(entry);
    }

    _cachedExercises = List.unmodifiable(list);
    _cachedById = Map.unmodifiable(byId);
  }

  /// True once [ensureLoaded] has completed.
  static bool get isLoaded => _cachedExercises != null;

  /// Throws [StateError] if [ensureLoaded] was not awaited first.
  static List<ExercisePoolEntry> getAll() {
    final cached = _cachedExercises;
    if (cached == null) {
      throw StateError(
        'ExerciseCatalog.ensureLoaded() must be awaited before use.',
      );
    }
    return cached;
  }

  static ExercisePoolEntry? findById(String id) {
    return _cachedById?[id];
  }

  static List<ExercisePoolEntry> where(
    bool Function(ExercisePoolEntry entry) predicate,
  ) {
    return getAll().where(predicate).toList();
  }

  static int get length => getAll().length;
}
