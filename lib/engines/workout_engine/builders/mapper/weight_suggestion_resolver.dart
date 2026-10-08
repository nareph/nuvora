// lib/engines/workout_engine/builders/mapper/weight_suggestion_resolver.dart

import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/enums/exports.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';

/// Computes a user-specific weight suggestion for one exercise.
///
/// The catalog itself does NOT carry a numeric weight — this resolver
/// is the single place where the user's profile is applied to produce
/// a qualitative suggestion ("Light" / "Moderate" / "Heavy" / ...).
///
/// The logic combines three inputs:
///
///   1. The exercise's intrinsic difficulty (from the catalog).
///   2. The user's experience level (from the profile).
///   3. The user's fitness goal (from the profile).
///
/// Returns null for exercises that should not display a weight
/// suggestion (bodyweight, timed, mobility).
class WeightSuggestionResolver {
  const WeightSuggestionResolver();

  /// Qualitative tiers, ordered from lightest (index 0) to heaviest.
  static const List<String> _tiers = [
    'Very Light',
    'Light',
    'Moderate',
    'Heavy',
    'Very Heavy',
  ];

  /// Bands cannot be quantified precisely — use simpler labels.
  static const List<String> _bandTiers = [
    'Light',
    'Light',
    'Moderate',
    'Heavy',
    'Heavy',
  ];

  String? resolve({
    required ExercisePoolEntry entry,
    required HealthProfile profile,
  }) {
    // ── 1. Never suggest a weight for non-weighted exercises.
    if (!entry.usesWeight) return null;
    if (entry.isTimed) return null;
    if (entry.category == ExerciseCategory.mobility) return null;

    // ── 2. Base tier from the exercise's intrinsic difficulty.
    final baseTier = _tierFromDifficulty(entry.difficulty);

    // ── 3. Shift based on the user's experience level.
    final experienceOffset = _experienceOffset(profile.training.experience);

    // ── 4. Shift based on the user's fitness goal.
    final goalOffset = _goalOffset(profile.training.goal);

    final adjusted = (baseTier + experienceOffset + goalOffset).clamp(0, 4);

    // ── 5. Bands use their own simplified labels.
    if (entry.equipmentType == EquipmentType.resistanceBands) {
      return _bandTiers[adjusted];
    }

    return _tiers[adjusted];
  }

  /// Maps exercise difficulty to a 0–4 tier index.
  int _tierFromDifficulty(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.beginner:
        return 1; // Light
      case ExerciseDifficulty.intermediate:
        return 2; // Moderate
      case ExerciseDifficulty.advanced:
        return 3; // Heavy
    }
  }

  /// Shifts the tier based on the user's experience level.
  int _experienceOffset(ExperienceLevel experience) {
    switch (experience) {
      case ExperienceLevel.beginner:
        return -1;
      case ExperienceLevel.intermediate:
        return 0;
      case ExperienceLevel.advanced:
        return 1;
    }
  }

  /// Shifts the tier based on the user's fitness goal.
  ///
  /// - Hypertrophy: standard, moderate-to-heavy range.
  /// - Strength:   heavier loads, lower reps → shift up.
  /// - Fat loss / endurance: lighter loads, higher reps → shift down.
  /// - General fitness: no shift.
  int _goalOffset(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.buildMuscle:
        return 0;
      case FitnessGoal.increaseStrength:
        return 1;
      case FitnessGoal.loseFat:
        return -1;
      case FitnessGoal.improveEndurance:
        return -1;
      case FitnessGoal.generalFitness:
        return 0;
    }
  }
}
