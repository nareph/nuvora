import 'package:gymgenius/domain/entities/exercise.dart';
import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/enums/experience_level.dart';
import 'package:gymgenius/engines/workout_engine/builders/description_builder.dart';
import 'package:gymgenius/engines/workout_engine/builders/difficulty_builder.dart';
import 'package:gymgenius/engines/workout_engine/builders/mapper/weight_suggestion_resolver.dart';
import 'package:gymgenius/engines/workout_engine/builders/reps_builder.dart';
import 'package:gymgenius/engines/workout_engine/builders/rest_builder.dart';
import 'package:gymgenius/engines/workout_engine/builders/sets_builder.dart';
import 'package:gymgenius/engines/workout_engine/builders/tempo_builder.dart';
import 'package:gymgenius/engines/workout_engine/builders/mapper/exercise_mapper.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';

class ExerciseBuilder {
  const ExerciseBuilder();

  /// [intensityOverride] is an optional regeneration hint ('harder' or
  /// 'easier'). It shifts the effective experience level used for
  /// sets/reps/difficulty by one step for THIS build call only — it never
  /// mutates the user's actual saved profile/experience level.
  Exercise build({
    required ExercisePoolEntry entry,
    required HealthProfile profile,
    String? intensityOverride,
  }) {
    final training = profile.training;
    final effectiveExperience =
        _applyIntensity(training.experience, intensityOverride);

    // NOTE: category and goal are now passed through — previously
    // SetsBuilder.build() was called with only `training.experience`,
    // which meant its compound-vs-isolation and goal-based volume logic
    // was unreachable dead code (both parameters are optional and were
    // always null in practice).
    final sets = SetsBuilder.build(
      effectiveExperience,
      category: entry.category,
      goal: training.goal,
    );

    final reps = RepsBuilder.build(
      experience: effectiveExperience,
      goal: training.goal,
      category: entry.category,
    );

    final rest = RestBuilder.build(
      goal: training.goal,
      category: entry.category,
    );

    final difficulty = DifficultyBuilder.build(
      effectiveExperience,
    );

    final tempo = TempoBuilder.build(
      entry.category,
    );

    final description = DescriptionBuilder.build(
      entry: entry,
    );

    // resolve the weight suggestion from the user profile.
    final weightSuggestion = const WeightSuggestionResolver().resolve(
      entry: entry,
      profile: profile,
    );

    return ExerciseMapper.toDomain(
      entry: entry,
      sets: sets,
      reps: reps,
      restSeconds: rest,
      difficulty: difficulty,
      tempo: tempo,
      description: description,
      weightSuggestion: weightSuggestion,
    );
  }

  static const List<ExperienceLevel> _ladder = [
    ExperienceLevel.beginner,
    ExperienceLevel.intermediate,
    ExperienceLevel.advanced,
  ];

  ExperienceLevel _applyIntensity(
    ExperienceLevel base,
    String? intensityOverride,
  ) {
    if (intensityOverride == null) return base;

    final index = _ladder.indexOf(base);
    if (index == -1) return base;

    if (intensityOverride == 'harder') {
      final next = index + 1;
      return next < _ladder.length ? _ladder[next] : base;
    }

    if (intensityOverride == 'easier') {
      final prev = index - 1;
      return prev >= 0 ? _ladder[prev] : base;
    }

    return base;
  }
}
