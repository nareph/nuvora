import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:gymgenius/engines/workout_engine/data/models/exercise_dataset_record.dart';
import 'package:gymgenius/engines/workout_engine/data/models/exercise_taxonomy_record.dart';

/// Loads `exercises.json` and `exercise_taxonomy.json` from the asset bundle.
///
/// Both files are cached in memory after the first successful load.
/// Call [preload] once at app startup (e.g. in `main()` before `runApp`).
class ExerciseDatasetLoader {
  ExerciseDatasetLoader._();

  static const String _datasetAsset = 'assets/exercises/exercises.json';
  static const String _taxonomyAsset =
      'assets/exercises/exercise_taxonomy.json';

  static List<ExerciseDatasetRecord>? _dataset;
  static Map<String, ExerciseTaxonomyRecord>? _taxonomy;

  /// Loads both files and populates the caches. Safe to call multiple
  /// times — subsequent calls are no-ops.
  static Future<void> preload() async {
    await Future.wait([
      _loadDataset(),
      _loadTaxonomy(),
    ]);
  }

  static Future<List<ExerciseDatasetRecord>> _loadDataset() async {
    final cached = _dataset;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_datasetAsset);
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final records =
        list.map(ExerciseDatasetRecord.fromJson).toList(growable: false);

    _dataset = records;
    return records;
  }

  static Future<Map<String, ExerciseTaxonomyRecord>> _loadTaxonomy() async {
    final cached = _taxonomy;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_taxonomyAsset);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final records = map.map(
      (id, value) => MapEntry(
        id,
        ExerciseTaxonomyRecord.fromJson(value as Map<String, dynamic>),
      ),
    );

    _taxonomy = records;
    return records;
  }

  /// Synchronous access — only valid AFTER [preload] has been awaited.
  /// Throws [StateError] if [preload] was not called.
  static List<ExerciseDatasetRecord> get datasetSync {
    final d = _dataset;
    if (d == null) {
      throw StateError(
        'ExerciseDatasetLoader.preload() must be awaited before use.',
      );
    }
    return d;
  }

  static Map<String, ExerciseTaxonomyRecord> get taxonomySync {
    final t = _taxonomy;
    if (t == null) {
      throw StateError(
        'ExerciseDatasetLoader.preload() must be awaited before use.',
      );
    }
    return t;
  }
}
