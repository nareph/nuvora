// lib/engines/workout_engine/selectors/selection_state.dart

import 'package:gymgenius/domain/enums/muscle_group.dart';
import 'package:gymgenius/engines/workout_engine/selectors/movement_family.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';

/// Mutable state used during the selection of ONE workout.
///
/// This object is the single source of truth for everything accumulated
/// while the selector builds the workout.
///
/// It tracks:
/// • selected exercises
/// • used exercise IDs (canonical identity)
/// • used normalized names (fallback guard)
/// • used movement patterns (coarse enum)
/// • used movement families (fine-grained, name-derived)
/// • primary muscle coverage
/// • secondary muscle coverage
class SelectionState {
  SelectionState();

  //==============================================================
  // Selected exercises
  //==============================================================

  final List<ExercisePoolEntry> selected = [];

  int get exerciseCount => selected.length;

  bool isComplete(int desiredCount) => selected.length >= desiredCount;

  //==============================================================
  // Duplicate protection – canonical ID is the primary key.
  // Normalized name is kept as a secondary safety net.
  //==============================================================

  /// Stores canonical exercise IDs to prevent duplicates.
  final Set<String> _usedExerciseIds = {};

  /// Stores normalized names to detect duplicates.
  final Set<String> _usedNormalizedNames = {};

  /// Normalize an exercise name by removing parentheticals, brackets,
  /// extra spaces, and converting to lowercase.
  static String _normalizeName(String name) {
    return name
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  /// Checks if an exercise with the given ID has already been selected.
  bool containsExerciseId(String id) {
    return _usedExerciseIds.contains(id);
  }

  /// Checks if an exercise with a name that normalizes to the same value
  /// has already been selected (legacy guard).
  bool containsExercise(String name) {
    return _usedNormalizedNames.contains(_normalizeName(name));
  }

  //==============================================================
  // Movement diversity — coarse (enum) and fine (family)
  //==============================================================

  final Set<String> _movementPatterns = {};

  /// Coarse tracking: broad movement pattern from the enum.
  bool containsPattern(String pattern) {
    return _movementPatterns.contains(pattern);
  }

  /// Fine-grained tracking: name-derived movement families.
  ///
  /// Two exercises in the same family are essentially the same movement
  /// with a different equipment, angle, or grip, e.g.:
  /// "Staggered Push-Up" and "Offset Bench Push-Up" both belong to the
  /// 'push-up' family and should not be chosen together on the same day.
  final Set<String> _movementFamilies = {};

  /// Returns true if an exercise of the given family has already been
  /// selected during this workout.
  bool containsFamily(String? family) {
    if (family == null) return false;

    return _movementFamilies.contains(family);
  }

  /// Returns how many exercises of the given family have been selected.
  ///
  /// Currently returns 0 or 1 (the set is a set), but kept as an int so
  /// future versions can count multiple selections of the same family
  /// if we decide to allow more than one.
  int familyCount(String? family) {
    if (family == null) return 0;

    return _movementFamilies.contains(family) ? 1 : 0;
  }

  //==============================================================
  // Muscle coverage
  //==============================================================

  final Map<MuscleGroup, int> _primaryCoverage = {};

  final Map<MuscleGroup, int> _secondaryCoverage = {};

  int coverageCount(MuscleGroup muscle) {
    return _primaryCoverage[muscle] ?? 0;
  }

  int secondaryCoverageCount(MuscleGroup muscle) {
    return _secondaryCoverage[muscle] ?? 0;
  }

  double totalCoverage(MuscleGroup muscle) {
    return coverageCount(muscle) + secondaryCoverageCount(muscle) * 0.5;
  }

  bool coversMuscle(MuscleGroup muscle) {
    return totalCoverage(muscle) > 0;
  }

  //==============================================================
  // Registration
  //==============================================================

  void add(ExercisePoolEntry entry) {
    selected.add(entry);

    // Primary: store canonical ID.
    _usedExerciseIds.add(entry.id);

    // Secondary: store normalized name.
    _usedNormalizedNames.add(_normalizeName(entry.name));

    // Coarse movement pattern.
    _movementPatterns.add(entry.movementPattern.name);

    // Fine-grained movement family (null-safe).
    final family = movementFamilyOf(entry.name);
    if (family != null) {
      _movementFamilies.add(family);
    }

    // Primary muscles.
    for (final muscle in entry.targetMuscles) {
      _primaryCoverage.update(
        muscle,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    // Secondary muscles.
    for (final muscle in entry.secondaryMuscles) {
      _secondaryCoverage.update(
        muscle,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }

  //==============================================================
  // Focus helpers
  //==============================================================

  bool hasCoveredAllFocusMuscles(List<MuscleGroup> focusMuscles) {
    if (focusMuscles.isEmpty) return true;

    return focusMuscles.every(coversMuscle);
  }

  int missingFocusMusclesCount(List<MuscleGroup> focusMuscles) {
    return focusMuscles.where((muscle) => !coversMuscle(muscle)).length;
  }

  //==============================================================
  // Reset
  //==============================================================

  void clear() {
    selected.clear();
    _usedExerciseIds.clear();
    _usedNormalizedNames.clear();
    _movementPatterns.clear();
    _movementFamilies.clear();
    _primaryCoverage.clear();
    _secondaryCoverage.clear();
  }
}
