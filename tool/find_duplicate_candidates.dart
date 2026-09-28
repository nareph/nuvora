// tool/find_duplicate_candidates.dart
//
// AUDIT TOOL — prints suspected duplicate exercises for human review.
// Never deletes or merges anything.
//
// IMPORTANT: this now pre-deduplicates by normalized name FIRST, using
// the exact same logic as generate_catalog_definitions.dart, before
// looking for further duplicates. Without this step, the same
// exercise defined identically in multiple split-specific source
// files (e.g. "Pull-ups" copy-pasted into back/, pull/,
// back_biceps/, and upper_body/) would show up as a "duplicate" here
// even though generate_catalog_definitions.dart already collapses it
// into one entry — that's not a real problem to fix, just something
// this tool used to report noisily. Only genuinely different-named
// duplicates (e.g. "Tricep Dips (chair)" vs "Bench Dips") survive to
// the two passes below.
//
// 1. SAME SIGNATURE — same equipment, movement pattern, mechanics,
//    force type, laterality, plane of motion, and target-muscle set.
//
// 2. SIMILAR DESCRIPTION — same equipment, descriptions share a large
//    fraction of their meaningful words. Lower confidence — always
//    read the description before deciding.
//
// Once confirmed: delete the redundant entry from its SOURCE split
// file (e.g. lib/.../splits/arms/bodyweight.dart), not from anything
// under catalog/definitions/ — that's regenerated and your edit would
// be overwritten. Then re-run generate_catalog_definitions.dart.
//
// Usage: dart run tool/find_duplicate_candidates.dart

import 'package:flutter/foundation.dart';
import 'package:gymgenius/domain/enums/exports.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercises/splits/exports.dart';

const double _descriptionSimilarityThreshold = 0.45;

void main() {
  final rawCount = _countRawEntries();
  final entries = _canonicalizeByName();

  if (kDebugMode) {
    print('📦 $rawCount raw entries across all split source files.');
    print('📦 ${entries.length} distinct exercises after name-based dedup '
        '(same as generate_catalog_definitions.dart).\n');
  }

  final signatureHits = _findSignatureDuplicates(entries);
  final descriptionHits = _findDescriptionDuplicates(entries, signatureHits);

  if (signatureHits.isEmpty && descriptionHits.isEmpty) {
    if (kDebugMode) {
      print(
          '✅ No duplicate candidates found among distinctly-named exercises.');
    }
    return;
  }

  if (signatureHits.isNotEmpty) {
    if (kDebugMode) {
      print('🔴 HIGH CONFIDENCE — different names, but same equipment/'
          'pattern/mechanics/force/laterality/plane and same target-muscle '
          'set:\n');
    }
    for (final group in signatureHits) {
      _printGroup(group);
    }
  }

  if (descriptionHits.isNotEmpty) {
    if (kDebugMode) {
      print('🟡 REVIEW NEEDED — same equipment, descriptions look alike, '
          'but attributes differ somewhat (read before merging):\n');
    }
    for (final pair in descriptionHits) {
      _printGroup(pair);
    }
  }

  final totalCandidates = signatureHits.fold<int>(0, (s, g) => s + g.length) +
      descriptionHits.fold<int>(0, (s, g) => s + g.length);
  if (kDebugMode) {
    print('🔎 $totalCandidates entries across '
        '${signatureHits.length + descriptionHits.length} suspected group(s). '
        'Nothing was changed — review and fix in the SOURCE split files.');
  }
}

// ============================================================
// Name-based canonicalization — mirrors
// generate_catalog_definitions.dart's _getCanonicalExercisesWithSplits(),
// so this tool only ever reports what will actually survive generation.
// ============================================================

final _allSources = <_NamedSource>[
  const _NamedSource('Chest', chestExercises),
  const _NamedSource('Back', backExercises),
  _NamedSource('Legs', legsExercises),
  _NamedSource('Core', coreExercises),
  const _NamedSource('Arms', armsExercises),
  const _NamedSource('Shoulders', shouldersExercises),
  const _NamedSource('Pull', pullExercises),
  _NamedSource('Push', pushExercises),
  const _NamedSource('Chest & Triceps', chestTricepsExercises),
  const _NamedSource('Back & Biceps', backBicepsExercises),
  _NamedSource('Upper Body', upperBodyExercises),
  _NamedSource('Lower Body', lowerBodyExercises),
];

int _countRawEntries() {
  return _allSources.fold<int>(0, (sum, s) => sum + s.exercises.length);
}

List<ExercisePoolEntry> _canonicalizeByName() {
  final byName = <String, ExercisePoolEntry>{};

  for (final source in _allSources) {
    for (final entry in source.exercises) {
      final key = _normalizeName(entry.name);
      // Keep the alphabetically-first id, exactly like the generator,
      // so which representative survives is deterministic.
      final existing = byName[key];
      if (existing == null || entry.id.compareTo(existing.id) < 0) {
        byName[key] = entry;
      }
    }
  }

  return byName.values.toList();
}

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

// ============================================================
// Pass 1 — attribute signature
// ============================================================

List<List<ExercisePoolEntry>> _findSignatureDuplicates(
  List<ExercisePoolEntry> entries,
) {
  final buckets = <String, List<ExercisePoolEntry>>{};

  for (final entry in entries) {
    buckets.putIfAbsent(_signature(entry), () => []).add(entry);
  }

  return buckets.values.where((group) => group.length > 1).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
}

String _signature(ExercisePoolEntry e) {
  final muscles = [...e.targetMuscles]
    ..sort((a, b) => a.name.compareTo(b.name));
  final musclesKey = muscles.map((m) => m.name).join(',');

  return [
    e.equipmentType.name,
    e.movementPattern.name,
    e.mechanics.name,
    e.forceType.name,
    e.laterality.name,
    e.planeOfMotion.name,
    musclesKey,
  ].join('|');
}

// ============================================================
// Pass 2 — description similarity (same equipment only)
// ============================================================

List<List<ExercisePoolEntry>> _findDescriptionDuplicates(
  List<ExercisePoolEntry> entries,
  List<List<ExercisePoolEntry>> alreadyFlagged,
) {
  final alreadyFlaggedIds =
      alreadyFlagged.expand((group) => group).map((e) => e.id).toSet();

  final byEquipment = <EquipmentType, List<ExercisePoolEntry>>{};
  for (final entry in entries) {
    if (alreadyFlaggedIds.contains(entry.id)) continue;
    byEquipment.putIfAbsent(entry.equipmentType, () => []).add(entry);
  }

  final pairs = <List<ExercisePoolEntry>>[];

  for (final group in byEquipment.values) {
    for (var i = 0; i < group.length; i++) {
      for (var j = i + 1; j < group.length; j++) {
        final a = group[i];
        final b = group[j];
        final similarity = _descriptionSimilarity(a.description, b.description);
        if (similarity >= _descriptionSimilarityThreshold) {
          pairs.add([a, b]);
        }
      }
    }
  }

  return pairs;
}

double _descriptionSimilarity(String a, String b) {
  final wordsA = _normalizeWords(a);
  final wordsB = _normalizeWords(b);
  if (wordsA.isEmpty || wordsB.isEmpty) return 0;

  final intersection = wordsA.intersection(wordsB).length;
  final union = wordsA.union(wordsB).length;
  return union == 0 ? 0 : intersection / union;
}

const _stopWords = {
  'the',
  'a',
  'an',
  'to',
  'your',
  'you',
  'on',
  'in',
  'and',
  'of',
  'with',
  'back',
  'up',
  'down',
  'target',
  'then',
  'from',
  'for',
  'at',
  'by',
  'while',
  'until',
  'as',
  'is',
  'are',
  'this',
  'that',
  'or',
  'into',
};

Set<String> _normalizeWords(String text) {
  final cleaned = text
      .replaceAll(RegExp(r'\*\*'), ' ')
      .replaceAll(RegExp(r'\\n'), ' ')
      .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
      .toLowerCase();

  return cleaned
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2 && !_stopWords.contains(w))
      .toSet();
}

// ============================================================
// Output
// ============================================================

void _printGroup(List<ExercisePoolEntry> group) {
  for (final entry in group) {
    if (kDebugMode) {
      print('  • ${entry.name}  [id: ${entry.id}]');

      print('      equipment: ${entry.equipmentType.name}, '
          'category: ${entry.category.name}, '
          'pattern: ${entry.movementPattern.name}');
      print('      target: ${entry.targetMuscles.map((m) => m.name).join(', ')}'
          '  secondary: ${entry.secondaryMuscles.map((m) => m.name).join(', ')}');
      print(
          '      "${entry.description.replaceAll('\n', ' ').replaceAll('**', '')}"');

      print('');
    }
  }
}

class _NamedSource {
  const _NamedSource(this.splitName, this.exercises);
  final String splitName;
  final List<ExercisePoolEntry> exercises;
}
