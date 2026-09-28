// tool/generate_catalog_definitions.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gymgenius/domain/enums/exports.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercises/splits/exports.dart';

void main() {
  final exercises = _getCanonicalExercisesWithSplits();
  final grouped = <String, List<ExercisePoolEntry>>{};

  for (final entry in exercises) {
    if (entry.targetMuscles.isEmpty) {
      continue;
    }

    final primaryMuscle = entry.targetMuscles.first;
    final key = _muscleToFileName(primaryMuscle);

    grouped.putIfAbsent(key, () => <ExercisePoolEntry>[]).add(entry);
  }

  final outputDir = Directory(
    'lib/engines/workout_engine/shared/exercises/catalog/definitions',
  );

  outputDir.createSync(recursive: true);

  for (final entry in grouped.entries) {
    final fileName = '${entry.key}_exercises.dart';
    final file = File('${outputDir.path}/$fileName');

    final sortedEntries = [...entry.value]
      ..sort((a, b) => a.id.compareTo(b.id));

    final content = _generateFileContent(
      entry.key,
      sortedEntries,
    );

    file.writeAsStringSync(content);

    if (kDebugMode) {
      print(
        '✅ Generated $fileName (${sortedEntries.length} exercises)',
      );
    }
  }

  _removeObsoleteFiles(outputDir);

  final total = grouped.values.fold<int>(
    0,
    (sum, entries) => sum + entries.length,
  );

  if (kDebugMode) {
    print('🎉 Done.');
    print('📦 Generated $total canonical exercise definitions.');
  }
}

/// Builds one canonical entry per DISTINCT EXERCISE.
///
/// Previously deduped by `entry.id` — but the same move is frequently
/// authored under different ids in different split-specific source
/// files (e.g. 'arms_bw_plank_shoulder_taps' vs
/// 'upper_bw_plank_shoulder_taps' for the identical "Plank Shoulder
/// Taps" exercise, or 'chest_chair_incline_pushup' vs
/// 'chest_triceps_chair_incline_push_ups' for "Incline Push-Up").
/// Deduping by id let these slip through as separate entries, which a
/// later `deduplicate_exercises.dart` script tried to catch by
/// re-parsing the GENERATED .dart source as text — fragile hand-rolled
/// parsing (brace/string counting) that's easy to get subtly wrong,
/// and running a second time after the fact.
///
/// Deduping by normalized NAME here instead — on the real typed
/// objects, before anything is written to disk — is simpler, can't
/// have parser bugs, and means `deduplicate_exercises.dart` is no
/// longer needed at all; delete it once this is in place.
List<ExercisePoolEntry> _getCanonicalExercisesWithSplits() {
  final canonical = <String, _CanonicalExercise>{};

  final sources = <_ExerciseSource>[
    _ExerciseSource(
      splitName: 'Chest',
      exercises: chestExercises,
    ),
    _ExerciseSource(
      splitName: 'Back',
      exercises: backExercises,
    ),
    _ExerciseSource(
      splitName: 'Legs',
      exercises: legsExercises,
    ),
    _ExerciseSource(
      splitName: 'Core',
      exercises: coreExercises,
    ),
    _ExerciseSource(
      splitName: 'Arms',
      exercises: armsExercises,
    ),
    _ExerciseSource(
      splitName: 'Shoulders',
      exercises: shouldersExercises,
    ),
    _ExerciseSource(
      splitName: 'Pull',
      exercises: pullExercises,
    ),
    _ExerciseSource(
      splitName: 'Push',
      exercises: pushExercises,
    ),
    _ExerciseSource(
      splitName: 'Chest & Triceps',
      exercises: chestTricepsExercises,
    ),
    _ExerciseSource(
      splitName: 'Back & Biceps',
      exercises: backBicepsExercises,
    ),
    _ExerciseSource(
      splitName: 'Upper Body',
      exercises: upperBodyExercises,
    ),
    _ExerciseSource(
      splitName: 'Lower Body',
      exercises: lowerBodyExercises,
    ),
  ];

  for (final source in sources) {
    for (final entry in source.exercises) {
      final key = _normalizeName(entry.name);
      final existing = canonical[key];

      if (existing == null) {
        canonical[key] = _CanonicalExercise(
          entry: entry,
          compatibleSplits: {
            source.splitName,
          },
        );
      } else {
        existing.compatibleSplits.add(source.splitName);

        // Keep the alphabetically-first id as canonical so the id
        // (and therefore the file's contents) stay stable across
        // regenerations, regardless of the order `sources` is
        // iterated in.
        if (entry.id.compareTo(existing.entry.id) < 0) {
          existing.entry = entry;
        }
      }
    }
  }

  return canonical.values
      .map(
        (item) => _withCompatibleSplits(
          item.entry,
          item.compatibleSplits,
        ),
      )
      .toList();
}

/// Normalizes an exercise name for duplicate detection: strips
/// parenthetical/bracketed qualifiers and punctuation, collapses
/// whitespace, lowercases.
///
/// Deliberately does NOT strip generic movement words (close/grip/
/// wide/narrow/curl/etc. — as a since-removed version of this script
/// once did) — doing so would conflate genuinely different exercises,
/// e.g. "Close-Grip Bench Press" and "Wide-Grip Bench Press" would
/// normalize to nearly the same string and wrongly merge. Two entries
/// are only treated as the same exercise when their full name matches
/// after this light normalization — same standard used for the
/// generated file's per-file dedup at the id level, applied globally.
String _normalizeName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  final words = cleaned.split(' ').map(_singularize).toList();
  return words.join(' ');
}

String _singularize(String word) {
  if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// Creates a new immutable [ExercisePoolEntry] containing the merged
/// split applicability metadata.
ExercisePoolEntry _withCompatibleSplits(
  ExercisePoolEntry source,
  Set<String> compatibleSplits,
) {
  return ExercisePoolEntry(
    id: source.id,
    name: source.name,
    category: source.category,
    difficulty: source.difficulty,
    equipmentType: source.equipmentType,
    targetMuscles: List<MuscleGroup>.unmodifiable(
      source.targetMuscles,
    ),
    secondaryMuscles: List<MuscleGroup>.unmodifiable(
      source.secondaryMuscles,
    ),
    compatibleSplits: Set<String>.unmodifiable(
      compatibleSplits,
    ),
    weightSuggestion: source.weightSuggestion,
    usesWeight: source.usesWeight,
    isTimed: source.isTimed,
    movementPattern: source.movementPattern,
    mechanics: source.mechanics,
    forceType: source.forceType,
    laterality: source.laterality,
    planeOfMotion: source.planeOfMotion,
    description: source.description,
  );
}

String _muscleToFileName(MuscleGroup muscle) {
  switch (muscle) {
    case MuscleGroup.chest:
      return 'chest';

    case MuscleGroup.back:
      return 'back';

    case MuscleGroup.shoulders:
    case MuscleGroup.traps:
      return 'shoulders';

    case MuscleGroup.biceps:
    case MuscleGroup.triceps:
    case MuscleGroup.forearms:
      return 'arms';

    case MuscleGroup.quadriceps:
    case MuscleGroup.hamstrings:
    case MuscleGroup.glutes:
    case MuscleGroup.calves:
    case MuscleGroup.adductors:
      return 'legs';

    case MuscleGroup.absCore:
      return 'core';
  }
}

String _generateFileContent(
  String groupName,
  List<ExercisePoolEntry> entries,
) {
  final buffer = StringBuffer();

  buffer.writeln(
    '// lib/engines/workout_engine/shared/exercises/'
    'catalog/definitions/${groupName}_exercises.dart',
  );
  buffer.writeln('// ⚠️ AUTO-GENERATED – DO NOT EDIT MANUALLY');
  buffer.writeln();
  buffer.writeln(
    "import 'package:gymgenius/domain/enums/exports.dart';",
  );
  buffer.writeln(
    "import 'package:gymgenius/engines/workout_engine/shared/"
    "exercise_pool_entry.dart';",
  );
  buffer.writeln();
  buffer.writeln(
    '/// Canonical definitions for $groupName exercises.',
  );
  buffer.writeln(
    'const List<ExercisePoolEntry> ${groupName}Definitions = [',
  );

  for (final entry in entries) {
    _writeExercise(buffer, entry);
  }

  buffer.writeln('];');

  return buffer.toString();
}

void _writeExercise(
  StringBuffer buffer,
  ExercisePoolEntry entry,
) {
  final sortedSplits = [...entry.compatibleSplits]..sort();

  buffer.writeln('  ExercisePoolEntry(');

  buffer.writeln(
    '    id: ${_dartString(entry.id)},',
  );

  buffer.writeln(
    '    name: ${_dartString(entry.name)},',
  );

  buffer.writeln(
    '    category: ${entry.category},',
  );

  buffer.writeln(
    '    difficulty: ${entry.difficulty},',
  );

  buffer.writeln(
    '    equipmentType: ${entry.equipmentType},',
  );

  buffer.writeln('    targetMuscles: [');
  for (final muscle in entry.targetMuscles) {
    buffer.writeln('      $muscle,');
  }
  buffer.writeln('    ],');

  buffer.writeln('    secondaryMuscles: [');
  for (final muscle in entry.secondaryMuscles) {
    buffer.writeln('      $muscle,');
  }
  buffer.writeln('    ],');

  buffer.writeln('    compatibleSplits: {');
  for (final split in sortedSplits) {
    buffer.writeln(
      '      ${_dartString(split)},',
    );
  }
  buffer.writeln('    },');

  if (entry.weightSuggestion != null) {
    buffer.writeln(
      '    weightSuggestion: '
      '${_dartString(entry.weightSuggestion!)},',
    );
  }

  buffer.writeln(
    '    usesWeight: ${entry.usesWeight},',
  );

  buffer.writeln(
    '    isTimed: ${entry.isTimed},',
  );

  buffer.writeln(
    '    movementPattern: ${entry.movementPattern},',
  );

  buffer.writeln(
    '    mechanics: ${entry.mechanics},',
  );

  buffer.writeln(
    '    forceType: ${entry.forceType},',
  );

  buffer.writeln(
    '    laterality: ${entry.laterality},',
  );

  buffer.writeln(
    '    planeOfMotion: ${entry.planeOfMotion},',
  );

  buffer.writeln(
    '    description: ${_dartString(entry.description)},',
  );

  buffer.writeln('  ),');
}

/// Safely generates a single-quoted Dart string.
String _dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');

  return "'$escaped'";
}

void _removeObsoleteFiles(Directory outputDir) {
  final obsoleteFiles = <String>[
    'other_exercises.dart',
  ];

  for (final fileName in obsoleteFiles) {
    final file = File('${outputDir.path}/$fileName');

    if (file.existsSync()) {
      file.deleteSync();

      if (kDebugMode) {
        print(
          '🗑️ Removed $fileName',
        );
      }
    }
  }
}

class _ExerciseSource {
  const _ExerciseSource({
    required this.splitName,
    required this.exercises,
  });

  final String splitName;
  final List<ExercisePoolEntry> exercises;
}

class _CanonicalExercise {
  _CanonicalExercise({
    required this.entry,
    required Set<String> compatibleSplits,
  }) : compatibleSplits = {...compatibleSplits};

  /// Mutable — reassigned when a later duplicate wins the
  /// alphabetically-first-id tiebreak (see _getCanonicalExercisesWithSplits).
  ExercisePoolEntry entry;
  final Set<String> compatibleSplits;
}
