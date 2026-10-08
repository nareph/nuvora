// lib/engines/workout_engine/services/generation_service.dart

import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/entities/training_program.dart';
import 'package:gymgenius/engines/workout_engine/models/muscle_split.dart';
import 'package:gymgenius/engines/workout_engine/models/workout_days_result.dart';
import 'package:gymgenius/engines/workout_engine/optimizers/local_program_optimizer.dart';
import 'package:gymgenius/engines/workout_engine/optimizers/program_optimizer.dart';
import 'package:gymgenius/engines/workout_engine/planner/split_planner.dart';
import 'package:gymgenius/engines/workout_engine/planner/workout_frequency_planner.dart';
import 'package:gymgenius/engines/workout_engine/program_generator.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercises/catalog/exercise_catalog.dart';
import 'package:gymgenius/engines/workout_engine/shared/profile_coherence.dart';
import 'package:gymgenius/engines/workout_engine/validators/program_validator.dart';

import '../../../domain/enums/exports.dart';

/// Orchestrates the complete Workout Engine generation pipeline.
class GenerationService {
  final ProgramGenerator _generator;
  final WorkoutFrequencyPlanner _frequencyPlanner;
  final SplitPlanner _splitPlanner;
  final List<ProgramOptimizer> _optimizers;
  final ProgramValidator _validator;

  static const _tag = 'GenerationService';

  GenerationService({
    ProgramGenerator? generator,
    WorkoutFrequencyPlanner? frequencyPlanner,
    SplitPlanner? splitPlanner,
    List<ProgramOptimizer>? optimizers,
    ProgramValidator? validator,
  })  : _generator = generator ?? ProgramGenerator(),
        _frequencyPlanner = frequencyPlanner ?? const WorkoutFrequencyPlanner(),
        _splitPlanner = splitPlanner ?? const SplitPlanner(),
        _optimizers = optimizers ??
            const [
              LocalProgramOptimizer(),
            ],
        _validator = validator ?? const ProgramValidator();

  Future<TrainingProgram> generate({
    required HealthProfile profile,
    TrainingProgram? previousProgram,
    Map<String, dynamic>? options,
  }) async {
    // lazy-load the exercise catalog before generation.
    // The catalog is no longer loaded at app startup — it is loaded
    // on the first call that actually needs it.
    await ExerciseCatalog.ensureLoaded();

    Log.debug(
      'GenerationService: Starting program generation',
      tag: _tag,
    );

    _logProfile(profile);

    final daysResult = _calculateWorkoutDays(profile);

    Log.debug(
      'GenerationService: Workout days = ${daysResult.count}, '
      'useSpecifiedDays = ${daysResult.useSpecifiedDays}',
      tag: _tag,
    );

    final selectedSplit = _determineSplit(
      daysResult.count,
      profile,
    );

    Log.debug(
      'GenerationService: Final split = '
      '${selectedSplit.map((split) => split.name).join(' → ')}',
      tag: _tag,
    );

    var program = _generator.generate(
      profile: profile,
      selectedSplit: selectedSplit,
      workoutDaysCount: daysResult.count,
      useSpecifiedDays: daysResult.useSpecifiedDays,
      previousProgram: previousProgram,
      excludeMuscles: ProfileCoherence.resolveAvoidedMuscles(
        profileAvoided: profile.training.avoidedMuscles,
        extra: _parseExcludeMuscles(options),
      ),
      intensityOverride: options?['intensity'] as String?,
    );

    Log.debug(
      'GenerationService: Local program generated '
      '(${daysResult.count} workout days / '
      '${program.weeklySchedule.length} calendar days)',
      tag: _tag,
    );

    _logGeneratedProgram(
      profile: profile,
      program: program,
    );

    for (final optimizer in _optimizers) {
      if (!optimizer.isAvailable) {
        continue;
      }

      try {
        program = await optimizer.optimize(
          program: program,
          profile: profile,
          options: options,
        );

        Log.debug(
          'GenerationService: Optimized with ${optimizer.runtimeType}',
          tag: _tag,
        );
      } catch (e) {
        Log.warning(
          'GenerationService: Optimizer ${optimizer.runtimeType} failed',
          tag: _tag,
          error: e,
        );
      }
    }

    _logGeneratedProgram(
      profile: profile,
      program: program,
      stage: 'after-optimization',
    );

    final valid = _validator.validate(program);

    if (!valid) {
      Log.warning(
        'GenerationService: Program validation failed.',
        tag: _tag,
      );
    }

    Log.debug(
      'GenerationService: Generation complete',
      tag: _tag,
    );

    return program;
  }

  //==============================================================
  // Workout frequency
  //==============================================================

  WorkoutDaysResult _calculateWorkoutDays(
    HealthProfile profile,
  ) {
    return _frequencyPlanner.calculateWorkoutDays(
      frequency: profile.training.frequency,
      preferredDays:
          profile.training.preferredDays.map((d) => d.value).toList(),
    );
  }

  //==============================================================
  // Split
  //==============================================================

  List<MuscleSplit> _determineSplit(
    int workoutDays,
    HealthProfile profile,
  ) {
    final focusMuscles = ProfileCoherence.resolveFocusAreas(
      goal: profile.training.goal,
      userFocusAreas: profile.training.focusAreas,
    );

    return _splitPlanner.plan(
      workoutDays: workoutDays,
      experience: profile.training.experience,
      focusMuscles: focusMuscles,
    );
  }

  //==============================================================
  // Debug logging
  //==============================================================

  void _logProfile(HealthProfile profile) {
    final training = profile.training;

    Log.debug(
      '''
GenerationService: User profile
--------------------------------
userId: ${profile.userId}
goal: ${training.goal.value}
experience: ${training.experience.name}
activityLevel: ${training.activityLevel.name}
frequency: ${training.frequency.name}
sessionDuration: ${training.sessionDuration.name}
preferredDays: ${training.preferredDays.map((d) => d.value).join(', ')}
equipment: ${training.equipment.map((e) => e.displayName).join(', ')}
focusAreas: ${training.focusAreas.map((m) => m.displayName).join(', ')}
avoidedMuscles: ${training.avoidedMuscles.map((m) => m.displayName).join(', ')}
country: ${profile.country}
--------------------------------
''',
      tag: _tag,
    );
  }

  void _logGeneratedProgram({
    required HealthProfile profile,
    required TrainingProgram program,
    String stage = 'after-local-generation',
  }) {
    final lines = <String>[
      '',
      'GenerationService: Generated program [$stage]',
      '============================================================',
      'Program ID: ${program.id}',
      'User ID: ${program.userId}',
      'Name: ${program.name}',
      'Goal: ${program.goal.value}',
      'Experience: ${program.experience.name}',
      'Duration: ${program.durationWeeks} weeks',
      'Generator: ${program.generatorType.name}',
      'Version: ${program.generatorVersion}',
      '------------------------------------------------------------',
    ];

    for (final day in program.weeklySchedule.entries) {
      if (day.value.isEmpty) {
        lines.add('${day.key}: REST');

        continue;
      }

      lines.add('${day.key.toUpperCase()}:');

      for (var i = 0; i < day.value.length; i++) {
        final exercise = day.value[i];

        lines.add(
          '  ${i + 1}. ${exercise.name} '
          '[sets=${exercise.sets}, reps=${exercise.reps}]',
        );
      }

      lines.add('');
    }

    lines.add(
      '============================================================',
    );

    Log.debug(
      lines.join('\n'),
      tag: _tag,
    );
  }

  //==============================================================
  // Options
  //==============================================================

  List<MuscleGroup>? _parseExcludeMuscles(
    Map<String, dynamic>? options,
  ) {
    final raw = options?['avoidMuscles'];

    if (raw is! List) {
      return null;
    }

    return raw
        .map(
          (value) => MuscleGroupExtension.fromValue(
            value.toString(),
          ),
        )
        .toList();
  }
}
