import 'package:gymgenius/domain/enums/equipment_type.dart';
import 'package:gymgenius/domain/enums/muscle_group.dart';
import 'package:gymgenius/engines/workout_engine/models/muscle_split.dart';
import 'package:gymgenius/engines/workout_engine/planner/split_catalog.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';

import 'catalog/exercise_catalog.dart';

/// Central repository of canonical exercises.
///
/// ExercisePool does not own exercise definitions.
/// It only queries and filters [ExerciseCatalog].
///
/// Split applicability is determined by:
/// - [ExercisePoolEntry.compatibleSplits] for standard splits.
/// - Target muscles for custom/focused splits.
/// - Muscle-based applicability for aggregate splits such as Full Body and
///   Shoulders & Core.
class ExercisePool {
  ExercisePool._();

  // ============================================================
  // Public API
  // ============================================================

  static List<ExercisePoolEntry> getExercises({
    required String splitName,
    required List<EquipmentType> allowedEquipment,
    List<MuscleGroup>? focusMuscles,
    List<MuscleGroup>? excludeMuscles,
    MuscleSplit? split,
  }) {
    final effectiveSplit = _resolveSplit(
      splitName,
      split,
      focusMuscles,
    );

    if (effectiveSplit == null || effectiveSplit.muscles.isEmpty) {
      return const <ExercisePoolEntry>[];
    }

    final catalogExercises = _getExercisesFromCatalog(
      splitName: splitName,
      split: effectiveSplit,
      allowedEquipment: allowedEquipment,
    );

    return _applyFilters(
      catalogExercises,
      excludeMuscles,
      focusMuscles,
    );
  }

  // ============================================================
  // Canonical catalog filtering
  // ============================================================

  static List<ExercisePoolEntry> _getExercisesFromCatalog({
    required String splitName,
    required MuscleSplit split,
    required List<EquipmentType> allowedEquipment,
  }) {
    final normalizedSplitName = splitName.trim();
    final splitMuscles = split.muscles.toSet();
    final allowedSet = allowedEquipment.toSet();

    final applicabilityMode = _resolveApplicabilityMode(
      splitName: normalizedSplitName,
      split: split,
    );

    return ExerciseCatalog.getAll().where((entry) {
      // Multi-equipment check: the user must have ALL required equipment
      // (primary + additional) for the exercise to be offered.
      if (!entry.allRequiredEquipment.every(allowedSet.contains)) {
        return false;
      }

      switch (applicabilityMode) {
        case _ApplicabilityMode.compatibleSplit:
          return entry.compatibleSplits.contains(
            normalizedSplitName,
          );

        case _ApplicabilityMode.strictMuscles:
          return _isMuscleCompatible(
            entry,
            splitMuscles,
            strict: true,
          );

        case _ApplicabilityMode.permissiveMuscles:
          return _isMuscleCompatible(
            entry,
            splitMuscles,
            strict: false,
          );
      }
    }).toList();
  }

  static _ApplicabilityMode _resolveApplicabilityMode({
    required String splitName,
    required MuscleSplit split,
  }) {
    final normalized = splitName.trim().toLowerCase();

    if (normalized.startsWith('focused:')) {
      return _ApplicabilityMode.strictMuscles;
    }

    final isKnownStandardSplit = SplitCatalog.byName(splitName.trim()) != null;

    if (!isKnownStandardSplit) {
      return _ApplicabilityMode.strictMuscles;
    }

    if (normalized == 'full body') {
      return _ApplicabilityMode.permissiveMuscles;
    }

    if (normalized == 'shoulders & core') {
      return _ApplicabilityMode.permissiveMuscles;
    }

    return _ApplicabilityMode.compatibleSplit;
  }

  static bool _isMuscleCompatible(
    ExercisePoolEntry entry,
    Set<MuscleGroup> splitMuscles, {
    required bool strict,
  }) {
    if (entry.targetMuscles.isEmpty) {
      return false;
    }

    if (strict) {
      return entry.targetMuscles.every(splitMuscles.contains);
    }

    return entry.targetMuscles.any(splitMuscles.contains);
  }

  // ============================================================
  // Additional filters
  // ============================================================

  static List<ExercisePoolEntry> _applyFilters(
    List<ExercisePoolEntry> exercises,
    List<MuscleGroup>? excludeMuscles,
    List<MuscleGroup>? focusMuscles,
  ) {
    var filtered = exercises;

    if (excludeMuscles != null && excludeMuscles.isNotEmpty) {
      final excludedSet = excludeMuscles.toSet();

      filtered = filtered.where((entry) {
        return !entry.targetMuscles.any(excludedSet.contains);
      }).toList();
    }

    if (focusMuscles != null && focusMuscles.isNotEmpty) {
      final focusSet = focusMuscles.toSet();

      filtered.sort((a, b) {
        final scoreA = _focusScore(
          entry: a,
          focusMuscles: focusSet,
          strict: false,
        );
        final scoreB = _focusScore(
          entry: b,
          focusMuscles: focusSet,
          strict: false,
        );
        return scoreB.compareTo(scoreA);
      });
    }

    return filtered;
  }

  // ============================================================
  // Split resolution
  // ============================================================

  static MuscleSplit? _resolveSplit(
    String splitName,
    MuscleSplit? providedSplit,
    List<MuscleGroup>? focusMuscles,
  ) {
    if (providedSplit != null) {
      return providedSplit;
    }

    final normalized = splitName.trim();

    if (normalized.isEmpty) {
      return null;
    }

    if (_isFocusedSplit(normalized)) {
      final focusSet = _parseFocusedMuscles(normalized);

      if (focusSet.isEmpty) {
        return null;
      }

      return MuscleSplit(
        name: normalized,
        theme: 'Focused',
        muscles: focusSet,
        recoveryCost: 1,
        isFullBody: false,
      );
    }

    final catalogSplit = SplitCatalog.byName(normalized);

    if (catalogSplit != null) {
      return catalogSplit;
    }

    if (focusMuscles != null && focusMuscles.isNotEmpty) {
      return MuscleSplit(
        name: normalized,
        theme: 'Custom Focus',
        muscles: List<MuscleGroup>.unmodifiable(focusMuscles),
        recoveryCost: 1,
        isFullBody: false,
      );
    }

    return null;
  }

  // ============================================================
  // Focused split helpers
  // ============================================================

  static bool _isFocusedSplit(String splitName) {
    return splitName.toLowerCase().startsWith('focused:');
  }

  static List<MuscleGroup> _parseFocusedMuscles(String splitName) {
    final lower = splitName.toLowerCase();

    if (!lower.startsWith('focused:')) {
      return const [];
    }

    var value = splitName.substring(splitName.indexOf(':') + 1);

    final dayIndex = value.toLowerCase().lastIndexOf(' day ');

    if (dayIndex != -1) {
      value = value.substring(0, dayIndex);
    }

    value = value.trim();

    if (value.isEmpty) {
      return const [];
    }

    final result = <MuscleGroup>[];

    final parts = value
        .split(RegExp(r'\s*&\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    for (final part in parts) {
      final muscle = _muscleFromDisplayName(part);

      if (muscle != null && !result.contains(muscle)) {
        result.add(muscle);
      }
    }

    return result;
  }

  static MuscleGroup? _muscleFromDisplayName(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ');

    for (final muscle in MuscleGroup.values) {
      final display = muscle.displayName
          .toLowerCase()
          .replaceAll('-', ' ')
          .replaceAll('_', ' ');

      if (display == normalized) {
        return muscle;
      }

      if (muscle == MuscleGroup.absCore &&
          (normalized == 'abs/core' ||
              normalized == 'abs core' ||
              normalized == 'core' ||
              normalized == 'abs')) {
        return MuscleGroup.absCore;
      }
    }

    return null;
  }

  // ============================================================
  // Focus scoring
  // ============================================================

  static int _focusScore({
    required ExercisePoolEntry entry,
    required Set<MuscleGroup> focusMuscles,
    required bool strict,
  }) {
    final matchingPrimary =
        entry.targetMuscles.where(focusMuscles.contains).length;

    if (!strict) {
      return matchingPrimary;
    }

    final allPrimaryMatch = entry.targetMuscles.isNotEmpty &&
        entry.targetMuscles.every(focusMuscles.contains);

    return allPrimaryMatch ? matchingPrimary : 0;
  }

  // ============================================================
  // Convenience methods
  // ============================================================

  static List<ExercisePoolEntry> getAllExercises() {
    return ExerciseCatalog.getAll();
  }

  static ExercisePoolEntry? findById(String id) {
    final normalized = id.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return ExerciseCatalog.findById(normalized);
  }

  static ExercisePoolEntry? findByName(
    String name, {
    required List<EquipmentType> allowedEquipment,
  }) {
    final normalized = name.trim().toLowerCase();

    if (normalized.isEmpty) {
      return null;
    }

    final allowedSet = allowedEquipment.toSet();

    for (final entry in ExerciseCatalog.getAll()) {
      if (!entry.allRequiredEquipment.every(allowedSet.contains)) {
        continue;
      }

      if (entry.name.trim().toLowerCase() == normalized) {
        return entry;
      }
    }

    return null;
  }

  static ExercisePoolEntry? findAlternative({
    required List<MuscleGroup> targetMuscles,
    required List<EquipmentType> allowedEquipment,
    Set<String> excludeNames = const {},
    List<MuscleGroup> excludeMuscles = const [],
  }) {
    ExercisePoolEntry? bestCandidate;
    var bestScore = -1;

    final targetSet = targetMuscles.toSet();
    final allowedSet = allowedEquipment.toSet();

    final normalizedExcludedNames =
        excludeNames.map((name) => name.trim().toLowerCase()).toSet();

    for (final entry in ExerciseCatalog.getAll()) {
      if (!entry.allRequiredEquipment.every(allowedSet.contains)) {
        continue;
      }

      if (normalizedExcludedNames.contains(
        entry.name.trim().toLowerCase(),
      )) {
        continue;
      }

      if (excludeMuscles.isNotEmpty &&
          entry.targetMuscles.any(excludeMuscles.contains)) {
        continue;
      }

      final score = entry.targetMuscles.where(targetSet.contains).length;

      if (score == 0) {
        continue;
      }

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = entry;
      }
    }

    return bestCandidate;
  }
}

enum _ApplicabilityMode {
  compatibleSplit,
  strictMuscles,
  permissiveMuscles,
}
