// lib/engines/workout_engine/services/regeneration_service.dart

import 'package:gymgenius/core/logger/logger_service.dart';

import 'package:gymgenius/domain/entities/exercise.dart';
import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/entities/training_program.dart';
import 'package:gymgenius/domain/enums/exports.dart';

import 'package:gymgenius/engines/workout_engine/generators/workout_day_generator.dart';
import 'package:gymgenius/engines/workout_engine/models/muscle_split.dart';
import 'package:gymgenius/engines/workout_engine/models/workout_days_result.dart';
import 'package:gymgenius/engines/workout_engine/planner/split_planner.dart';
import 'package:gymgenius/engines/workout_engine/planner/workout_frequency_planner.dart';
import 'package:gymgenius/engines/workout_engine/services/generation_service.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercises/catalog/exercise_catalog.dart';
import 'package:gymgenius/engines/workout_engine/shared/profile_coherence.dart';
import 'package:gymgenius/engines/workout_engine/shared/workout_constants.dart';

/// Handles program regeneration with specific options.
///
/// `options` comes from `RegenerationOptions.toMap()`.
///
/// Supported regeneration types:
///
/// - `specificDay`
///   Regenerates ONLY the requested day.
///
/// - `singleExercise`
///   Replaces ONE exercise within the requested day.
///
/// - `fullProgram` / `withPreferences`
///   Regenerates every scheduled day.
///
/// When `keepStructure == true`, the existing workout-day structure is
/// preserved as much as the currently available domain information allows:
///
/// • same scheduled workout days
/// • same number of exercises per day
/// • same planner-derived split mapping for the current profile
///
/// When `keepStructure == false`, the complete program is regenerated from
/// scratch through [GenerationService].
class RegenerationService {
  final GenerationService _generationService;
  final WorkoutDayGenerator _dayGenerator;
  final WorkoutFrequencyPlanner _frequencyPlanner;
  final SplitPlanner _splitPlanner;

  static const _tag = 'RegenerationService';

  RegenerationService({
    GenerationService? generationService,
    WorkoutDayGenerator? dayGenerator,
    WorkoutFrequencyPlanner? frequencyPlanner,
    SplitPlanner? splitPlanner,
  })  : _generationService = generationService ?? GenerationService(),
        _dayGenerator = dayGenerator ?? WorkoutDayGenerator(),
        _frequencyPlanner = frequencyPlanner ?? const WorkoutFrequencyPlanner(),
        _splitPlanner = splitPlanner ?? const SplitPlanner();

  //===========================================================================
  // Public API
  //===========================================================================

  Future<TrainingProgram> regenerate({
    required HealthProfile profile,
    required TrainingProgram previousProgram,
    required Map<String, dynamic> options,
  }) async {
    // Lazy-load the exercise catalog before regeneration.
    // The catalog is no longer loaded at app startup — it is loaded
    // on the first call that actually needs it. Doing it here as well
    // covers the "specificDay" and "singleExercise" branches which
    // don't delegate to GenerationService.
    await ExerciseCatalog.ensureLoaded();

    final type = options['type'] as String?;

    Log.debug(
      '''
============================================================
RegenerationService: START
============================================================
type: $type
userId: ${profile.userId}
previousProgramId: ${previousProgram.id}
previousProgramName: ${previousProgram.name}
options: $options
============================================================
''',
      tag: _tag,
    );

    _logProgramSnapshot(
      program: previousProgram,
      stage: 'BEFORE-REGENERATION',
    );

    if (type == 'specificDay') {
      final targetDay = options['targetDay'] as String?;

      if (targetDay == null) {
        Log.warning(
          'type=specificDay but targetDay is missing '
          '— returning program unchanged.',
          tag: _tag,
        );

        return previousProgram;
      }

      return _regenerateSingleDay(
        profile: profile,
        previousProgram: previousProgram,
        targetDay: targetDay.toLowerCase(),
        options: options,
      );
    }

    if (type == 'singleExercise') {
      final targetDay = options['targetDay'] as String?;
      final targetExerciseId = options['targetExerciseId'] as String?;

      if (targetDay == null || targetExerciseId == null) {
        Log.warning(
          'type=singleExercise but targetDay/targetExerciseId is missing '
          '— returning program unchanged.',
          tag: _tag,
        );

        return previousProgram;
      }

      return _regenerateSingleExercise(
        profile: profile,
        previousProgram: previousProgram,
        targetDay: targetDay.toLowerCase(),
        targetExerciseId: targetExerciseId,
        options: options,
      );
    }

    return _regenerateFullProgram(
      profile: profile,
      previousProgram: previousProgram,
      options: options,
    );
  }

  //===========================================================================
  // Single-day regeneration
  //===========================================================================

  Future<TrainingProgram> _regenerateSingleDay({
    required HealthProfile profile,
    required TrainingProgram previousProgram,
    required String targetDay,
    required Map<String, dynamic> options,
  }) async {
    Log.debug(
      '''
------------------------------------------------------------
RegenerationService: SPECIFIC DAY
------------------------------------------------------------
targetDay: $targetDay
------------------------------------------------------------
''',
      tag: _tag,
    );

    final adjustedProfile = _profileWithAdjustments(
      profile,
      options,
    );

    final split = _findSplitForDay(
      adjustedProfile,
      targetDay,
    );

    if (split == null) {
      Log.warning(
        '"$targetDay" is not a scheduled workout day in the current split '
        '— nothing to regenerate, returning the program unchanged.',
        tag: _tag,
      );

      return previousProgram;
    }

    Log.debug(
      'Target day split: ${split.name}',
      tag: _tag,
    );

    //--------------------------------------------------------------------------
    // Keep all exercise IDs from the other days.
    //--------------------------------------------------------------------------

    final weeklyUsedExerciseIds = <String>{};

    for (final entry in previousProgram.weeklySchedule.entries) {
      if (entry.key == targetDay) {
        continue;
      }

      for (final exercise in entry.value) {
        weeklyUsedExerciseIds.add(exercise.id);
      }
    }

    _logWeeklyUsedIds(
      day: targetDay,
      weeklyUsedExerciseIds: weeklyUsedExerciseIds,
      context: 'BEFORE SPECIFIC-DAY GENERATION',
    );

    final previousDayExercises =
        previousProgram.weeklySchedule[targetDay] ?? const <Exercise>[];

    _logDayExercises(
      day: targetDay,
      exercises: previousDayExercises,
      context: 'PREVIOUS DAY',
    );

    //--------------------------------------------------------------------------
    // Regenerate only the requested day.
    //--------------------------------------------------------------------------

    final newDayExercises = _dayGenerator.generate(
      split: split,
      profile: adjustedProfile,
      previousProgram: previousProgram,
      excludeMuscles: _parseExcludeMuscles(options),
      intensityOverride: _intensityString(options),
      weeklyUsedExerciseIds: weeklyUsedExerciseIds,
    );

    _logDayExercises(
      day: targetDay,
      exercises: newDayExercises,
      context: 'NEW DAY AFTER GENERATION',
    );

    _logDuplicateIds(
      exercises: newDayExercises,
      context: 'SPECIFIC-DAY RESULT',
    );

    final updatedSchedule = Map<String, List<Exercise>>.from(
      previousProgram.weeklySchedule,
    );

    updatedSchedule[targetDay] = newDayExercises;

    final updatedProgram = previousProgram.copyWith(
      weeklySchedule: updatedSchedule,
    );

    _logProgramSnapshot(
      program: updatedProgram,
      stage: 'AFTER-SPECIFIC-DAY-REGENERATION',
    );

    _logWeeklyDuplicateIds(
      program: updatedProgram,
      context: 'AFTER SPECIFIC-DAY REGENERATION',
    );

    Log.debug(
      '''
RegenerationService: END SPECIFIC DAY
day=$targetDay
oldCount=${previousDayExercises.length}
newCount=${newDayExercises.length}
''',
      tag: _tag,
    );

    return updatedProgram;
  }

  //===========================================================================
  // Single-exercise regeneration
  //===========================================================================

  Future<TrainingProgram> _regenerateSingleExercise({
    required HealthProfile profile,
    required TrainingProgram previousProgram,
    required String targetDay,
    required String targetExerciseId,
    required Map<String, dynamic> options,
  }) async {
    Log.debug(
      '''
------------------------------------------------------------
RegenerationService: SINGLE EXERCISE
------------------------------------------------------------
targetDay: $targetDay
targetExerciseId: $targetExerciseId
------------------------------------------------------------
''',
      tag: _tag,
    );

    final dayExercises = previousProgram.weeklySchedule[targetDay];

    if (dayExercises == null || dayExercises.isEmpty) {
      Log.warning(
        '"$targetDay" has no exercises to replace '
        '— returning program unchanged.',
        tag: _tag,
      );

      return previousProgram;
    }

    final targetIndex = _findTargetExerciseIndex(
      dayExercises,
      targetExerciseId,
    );

    if (targetIndex == -1) {
      Log.warning(
        'Could not find exercise "$targetExerciseId" on "$targetDay" '
        '— returning program unchanged.',
        tag: _tag,
      );

      return previousProgram;
    }

    final targetExercise = dayExercises[targetIndex];

    Log.debug(
      '''
Target exercise found:
index: $targetIndex
name: ${targetExercise.name}
id: ${targetExercise.id}
''',
      tag: _tag,
    );

    final adjustedProfile = _profileWithAdjustments(
      profile,
      options,
    );

    final split = _findSplitForDay(
      adjustedProfile,
      targetDay,
    );

    if (split == null) {
      Log.warning(
        '"$targetDay" is not a scheduled workout day in the current split '
        '— returning program unchanged.',
        tag: _tag,
      );

      return previousProgram;
    }

    Log.debug(
      'Target day split: ${split.name}',
      tag: _tag,
    );

    //--------------------------------------------------------------------------
    // Collect every exercise ID already present in the program.
    //--------------------------------------------------------------------------

    final weeklyUsedExerciseIds = <String>{};

    for (final entry in previousProgram.weeklySchedule.entries) {
      for (final exercise in entry.value) {
        weeklyUsedExerciseIds.add(exercise.id);
      }
    }

    _logWeeklyUsedIds(
      day: targetDay,
      weeklyUsedExerciseIds: weeklyUsedExerciseIds,
      context: 'BEFORE SINGLE-EXERCISE GENERATION',
    );

    //--------------------------------------------------------------------------
    // Remove the exercise currently being replaced.
    //--------------------------------------------------------------------------

    weeklyUsedExerciseIds.remove(
      targetExerciseId,
    );

    Log.debug(
      'Removed target exercise ID from weekly exclusion set: '
      '$targetExerciseId',
      tag: _tag,
    );

    _logWeeklyUsedIds(
      day: targetDay,
      weeklyUsedExerciseIds: weeklyUsedExerciseIds,
      context: 'AFTER REMOVING TARGET EXERCISE',
    );

    //--------------------------------------------------------------------------
    // Generate one replacement.
    //--------------------------------------------------------------------------

    final replacementDay = _dayGenerator.generate(
      split: split,
      profile: adjustedProfile,
      previousProgram: previousProgram,
      excludeMuscles: _parseExcludeMuscles(options),
      intensityOverride: _intensityString(options),
      desiredCountOverride: 1,
      weeklyUsedExerciseIds: weeklyUsedExerciseIds,
    );

    _logDayExercises(
      day: targetDay,
      exercises: replacementDay,
      context: 'REPLACEMENT RESULT',
    );

    if (replacementDay.isEmpty) {
      Log.warning(
        'No replacement exercise found for "$targetDay" '
        '(equipment/exclusions may be too restrictive) '
        '— returning program unchanged.',
        tag: _tag,
      );

      return previousProgram;
    }

    final updatedDayExercises = List<Exercise>.from(dayExercises);

    updatedDayExercises[targetIndex] = replacementDay.first;

    final updatedSchedule = Map<String, List<Exercise>>.from(
      previousProgram.weeklySchedule,
    );

    updatedSchedule[targetDay] = updatedDayExercises;

    final updatedProgram = previousProgram.copyWith(
      weeklySchedule: updatedSchedule,
    );

    _logDayExercises(
      day: targetDay,
      exercises: updatedDayExercises,
      context: 'UPDATED DAY',
    );

    _logDuplicateIds(
      exercises: updatedDayExercises,
      context: 'SINGLE-EXERCISE UPDATED DAY',
    );

    _logProgramSnapshot(
      program: updatedProgram,
      stage: 'AFTER-SINGLE-EXERCISE-REGENERATION',
    );

    _logWeeklyDuplicateIds(
      program: updatedProgram,
      context: 'AFTER SINGLE-EXERCISE REGENERATION',
    );

    Log.debug(
      'Replaced exercise at index $targetIndex on "$targetDay" '
      '("${dayExercises[targetIndex].name}" '
      '-> "${replacementDay.first.name}"). '
      'Day exercise count: ${updatedDayExercises.length} (unchanged).',
      tag: _tag,
    );

    return updatedProgram;
  }

  int _findTargetExerciseIndex(
    List<Exercise> dayExercises,
    String targetExerciseId,
  ) {
    //--------------------------------------------------------------------------
    // Primary lookup: canonical exercise ID.
    //--------------------------------------------------------------------------

    final byId = dayExercises.indexWhere(
      (exercise) => exercise.id == targetExerciseId,
    );

    if (byId != -1) {
      return byId;
    }

    //--------------------------------------------------------------------------
    // Backward-compatible fallback.
    //--------------------------------------------------------------------------

    final match = RegExp(
      r'^exercise_(\d+)$',
    ).firstMatch(targetExerciseId);

    if (match != null) {
      final index = int.tryParse(
        match.group(1)!,
      );

      if (index != null && index >= 0 && index < dayExercises.length) {
        return index;
      }
    }

    return -1;
  }

  //===========================================================================
  // Full-program regeneration
  //===========================================================================

  Future<TrainingProgram> _regenerateFullProgram({
    required HealthProfile profile,
    required TrainingProgram previousProgram,
    required Map<String, dynamic> options,
  }) async {
    final adjustedProfile = _profileWithAdjustments(
      profile,
      options,
    );

    final keepStructure = options['keepStructure'] as bool? ?? true;

    Log.debug(
      '''
------------------------------------------------------------
RegenerationService: FULL PROGRAM
------------------------------------------------------------
keepStructure: $keepStructure
------------------------------------------------------------
''',
      tag: _tag,
    );

    if (!keepStructure) {
      Log.debug(
        '-> from-scratch regeneration via GenerationService',
        tag: _tag,
      );

      final program = await _generationService.generate(
        profile: adjustedProfile,
        previousProgram: previousProgram,
        options: options,
      );

      _logProgramSnapshot(
        program: program,
        stage: 'AFTER-FULL-FROM-SCRATCH-REGENERATION',
      );

      _logWeeklyDuplicateIds(
        program: program,
        context: 'AFTER FULL FROM-SCRATCH REGENERATION',
      );

      return program;
    }

    final program = await _regenerateKeepingStructure(
      profile: adjustedProfile,
      previousProgram: previousProgram,
      options: options,
    );

    _logProgramSnapshot(
      program: program,
      stage: 'AFTER-FULL-STRUCTURE-PRESERVING-REGENERATION',
    );

    _logWeeklyDuplicateIds(
      program: program,
      context: 'AFTER FULL STRUCTURE-PRESERVING REGENERATION',
    );

    return program;
  }

  Future<TrainingProgram> _regenerateKeepingStructure({
    required HealthProfile profile,
    required TrainingProgram previousProgram,
    required Map<String, dynamic> options,
  }) async {
    //-----------------------------------------------------------------------
    // Preserve the actual workout days from the previous program.
    //-----------------------------------------------------------------------

    final workoutDays = previousProgram.weeklySchedule.entries
        .where(
          (entry) => entry.value.isNotEmpty,
        )
        .map(
          (entry) => entry.key,
        )
        .toList();

    Log.debug(
      'Workout days preserved: ${workoutDays.join(', ')}',
      tag: _tag,
    );

    if (workoutDays.isEmpty) {
      Log.warning(
        'previousProgram has no workout days to preserve '
        '— falling back to a full from-scratch regeneration.',
        tag: _tag,
      );

      return _generationService.generate(
        profile: profile,
        previousProgram: previousProgram,
        options: options,
      );
    }

    //-----------------------------------------------------------------------
    // Re-plan the split structure using the current profile.
    //-----------------------------------------------------------------------

    final selectedSplit = _planSplitsForWorkoutDays(
      profile: profile,
      workoutDayCount: workoutDays.length,
    );

    Log.debug(
      'Selected splits for regeneration: '
      '${selectedSplit.map((split) => split.name).join(' → ')}',
      tag: _tag,
    );

    if (selectedSplit.length != workoutDays.length) {
      Log.warning(
        'SplitPlanner returned ${selectedSplit.length} splits for '
        '${workoutDays.length} workout days '
        '— falling back to from-scratch generation.',
        tag: _tag,
      );

      return _generationService.generate(
        profile: profile,
        previousProgram: previousProgram,
        options: options,
      );
    }

    //-----------------------------------------------------------------------
    // Initialize schedule.
    //-----------------------------------------------------------------------

    final updatedSchedule = <String, List<Exercise>>{
      for (final day in WorkoutConstants.daysOfWeek) day: <Exercise>[],
    };

    final excludeMuscles = _parseExcludeMuscles(options);

    final intensityOverride = _intensityString(options);

    //-----------------------------------------------------------------------
    // Track newly generated canonical exercise IDs across the entire week.
    //-----------------------------------------------------------------------

    final weeklyUsedExerciseIds = <String>{};

    Log.debug(
      'Weekly used exercise IDs initialized as empty.',
      tag: _tag,
    );

    //-----------------------------------------------------------------------
    // Regenerate each scheduled day.
    //-----------------------------------------------------------------------

    for (var i = 0; i < workoutDays.length && i < selectedSplit.length; i++) {
      final day = workoutDays[i];
      final split = selectedSplit[i];

      final previousExercises =
          previousProgram.weeklySchedule[day] ?? const <Exercise>[];

      final desiredCount = previousExercises.length;

      Log.debug(
        '''
============================================================
RegenerationService: GENERATING DAY
------------------------------------------------------------
day: $day
split: ${split.name}
dayIndex: $i
desiredCount: $desiredCount
weeklyUsedCount BEFORE: ${weeklyUsedExerciseIds.length}
============================================================
''',
        tag: _tag,
      );

      _logWeeklyUsedIds(
        day: day,
        weeklyUsedExerciseIds: weeklyUsedExerciseIds,
        context: 'BEFORE DAY GENERATION',
      );

      _logDayExercises(
        day: day,
        exercises: previousExercises,
        context: 'PREVIOUS DAY BEFORE REGENERATION',
      );

      final dayExercises = _dayGenerator.generate(
        split: split,
        profile: profile,
        previousProgram: previousProgram,
        excludeMuscles: excludeMuscles,
        intensityOverride: intensityOverride,
        desiredCountOverride: desiredCount,
        weeklyUsedExerciseIds: weeklyUsedExerciseIds,
      );

      //---------------------------------------------------------------------
      // Log the result BEFORE adding IDs to the weekly set.
      //---------------------------------------------------------------------

      _logDayExercises(
        day: day,
        exercises: dayExercises,
        context: 'NEW DAY RESULT',
      );

      _logDuplicateIds(
        exercises: dayExercises,
        context: 'NEW DAY RESULT',
      );

      //---------------------------------------------------------------------
      // Detect collision with previous days immediately.
      //---------------------------------------------------------------------

      final duplicateWithPreviousDays = dayExercises
          .where(
            (exercise) => weeklyUsedExerciseIds.contains(
              exercise.id,
            ),
          )
          .toList();

      if (duplicateWithPreviousDays.isNotEmpty) {
        Log.warning(
          '''
⚠️ WEEKLY DUPLICATE DETECTED DURING REGENERATION
day: $day
split: ${split.name}
duplicates:
${duplicateWithPreviousDays.map(
                (exercise) => '  - ${exercise.name} [id=${exercise.id}]',
              ).join('\n')}
''',
          tag: _tag,
        );
      } else {
        Log.debug(
          '✅ No collision with previously generated days for "$day".',
          tag: _tag,
        );
      }

      updatedSchedule[day] = dayExercises;

      //---------------------------------------------------------------------
      // Register selected canonical exercise IDs.
      //---------------------------------------------------------------------

      for (final exercise in dayExercises) {
        final wasAlreadyUsed = weeklyUsedExerciseIds.contains(
          exercise.id,
        );

        weeklyUsedExerciseIds.add(
          exercise.id,
        );

        if (wasAlreadyUsed) {
          Log.warning(
            'Exercise ID already existed in weekly set when adding: '
            '${exercise.id} (${exercise.name})',
            tag: _tag,
          );
        }
      }

      //---------------------------------------------------------------------
      // Log weekly state AFTER this day.
      //---------------------------------------------------------------------

      _logWeeklyUsedIds(
        day: day,
        weeklyUsedExerciseIds: weeklyUsedExerciseIds,
        context: 'AFTER DAY GENERATION',
      );

      Log.debug(
        '''
RegenerationService: DAY COMPLETE
day: $day
selectedExercises: ${dayExercises.length}
weeklyUsedCount AFTER: ${weeklyUsedExerciseIds.length}
------------------------------------------------------------
''',
        tag: _tag,
      );
    }

    //-----------------------------------------------------------------------
    // Build resulting program.
    //-----------------------------------------------------------------------

    final updatedProgram = previousProgram.copyWith(
      weeklySchedule: updatedSchedule,
    );

    _logProgramSnapshot(
      program: updatedProgram,
      stage: 'FINAL STRUCTURE-PRESERVING RESULT',
    );

    _logWeeklyDuplicateIds(
      program: updatedProgram,
      context: 'FINAL STRUCTURE-PRESERVING RESULT',
    );

    Log.debug(
      'Regenerated all ${workoutDays.length} days '
      'keeping workout days and per-day exercise counts.',
      tag: _tag,
    );

    return updatedProgram;
  }

  //===========================================================================
  // Split planning
  //===========================================================================

  List<MuscleSplit> _planSplitsForWorkoutDays({
    required HealthProfile profile,
    required int workoutDayCount,
  }) {
    final focusMuscles = ProfileCoherence.resolveFocusAreas(
      goal: profile.training.goal,
      userFocusAreas: profile.training.focusAreas,
    );

    Log.debug(
      '''
Split planning:
workoutDayCount: $workoutDayCount
focusMuscles: ${focusMuscles.map((m) => m.displayName).join(', ')}
experience: ${profile.training.experience.name}
''',
      tag: _tag,
    );

    return _splitPlanner.plan(
      workoutDays: workoutDayCount,
      experience: profile.training.experience,
      focusMuscles: focusMuscles,
    );
  }

  //===========================================================================
  // Split resolution for one day
  //===========================================================================

  MuscleSplit? _findSplitForDay(
    HealthProfile profile,
    String targetDay,
  ) {
    final training = profile.training;

    final daysResult = _frequencyPlanner.calculateWorkoutDays(
      frequency: training.frequency,
      preferredDays: training.preferredDays
          .map(
            (day) => day.value,
          )
          .toList(),
    );

    final workoutDays = _resolveWorkoutDays(
      profile: profile,
      daysResult: daysResult,
    );

    final focusMuscles = ProfileCoherence.resolveFocusAreas(
      goal: training.goal,
      userFocusAreas: training.focusAreas,
    );

    final selectedSplit = _splitPlanner.plan(
      workoutDays: workoutDays.length,
      experience: training.experience,
      focusMuscles: focusMuscles,
    );

    Log.debug(
      '''
Find split for day:
targetDay: $targetDay
resolvedWorkoutDays: ${workoutDays.join(', ')}
resolvedSplits: ${selectedSplit.map((split) => split.name).join(' → ')}
''',
      tag: _tag,
    );

    if (selectedSplit.length != workoutDays.length) {
      Log.warning(
        'Split count (${selectedSplit.length}) does not match '
        'workout day count (${workoutDays.length}).',
        tag: _tag,
      );

      return null;
    }

    final normalizedTargetDay = targetDay.trim().toLowerCase();

    final dayIndex = workoutDays.indexWhere(
      (day) => day.trim().toLowerCase() == normalizedTargetDay,
    );

    if (dayIndex == -1 || dayIndex >= selectedSplit.length) {
      return null;
    }

    final resolvedSplit = selectedSplit[dayIndex];

    Log.debug(
      'Resolved "$targetDay" -> split "${resolvedSplit.name}" '
      '(index=$dayIndex)',
      tag: _tag,
    );

    return resolvedSplit;
  }

  List<String> _resolveWorkoutDays({
    required HealthProfile profile,
    required WorkoutDaysResult daysResult,
  }) {
    final training = profile.training;

    if (daysResult.useSpecifiedDays && training.preferredDays.isNotEmpty) {
      return training.preferredDays
          .map(
            (day) => day.value,
          )
          .take(7)
          .toList();
    }

    return WorkoutConstants.defaultWorkoutDays(
      daysResult.count.clamp(1, 7),
    );
  }

  //===========================================================================
  // Profile adjustments
  //===========================================================================

  HealthProfile _profileWithAdjustments(
    HealthProfile profile,
    Map<String, dynamic> options,
  ) {
    var training = profile.training;
    var changed = false;

    //-----------------------------------------------------------------------
    // Focus muscles
    //-----------------------------------------------------------------------

    final focusRaw = options['focusMuscles'];

    if (focusRaw is List && focusRaw.isNotEmpty) {
      final requested = focusRaw
          .map(
            (value) => MuscleGroupExtension.fromValue(
              value.toString(),
            ),
          )
          .toSet()
          .toList();

      if (requested.isNotEmpty &&
          !_sameMuscleList(
            training.focusAreas,
            requested,
          )) {
        training = training.copyWith(
          focusAreas: requested,
        );

        changed = true;

        Log.debug(
          'Profile adjustment: focusAreas changed to '
          '${requested.map((m) => m.displayName).join(', ')}',
          tag: _tag,
        );
      }
    }

    //-----------------------------------------------------------------------
    // Equipment
    //-----------------------------------------------------------------------

    final newEquipment = options['newEquipment'] as String?;

    if (newEquipment != null) {
      final equipment = EquipmentTypeExtension.fromValue(
        newEquipment,
      );

      if (!training.equipment.contains(
        equipment,
      )) {
        training = training.copyWith(
          equipment: [
            ...training.equipment,
            equipment,
          ],
        );

        changed = true;

        Log.debug(
          'Profile adjustment: added equipment '
          '${equipment.displayName}',
          tag: _tag,
        );
      }
    }

    //-----------------------------------------------------------------------
    // Avoided muscles
    //-----------------------------------------------------------------------

    final avoidRaw = options['avoidMuscles'];

    if (avoidRaw is List && avoidRaw.isNotEmpty) {
      final extra = avoidRaw
          .map(
            (value) => MuscleGroupExtension.fromValue(
              value.toString(),
            ),
          )
          .toSet()
          .toList();

      final merged = {
        ...training.avoidedMuscles,
        ...extra,
      }.toList();

      if (!_sameMuscleList(
        training.avoidedMuscles,
        merged,
      )) {
        training = training.copyWith(
          avoidedMuscles: merged,
        );

        changed = true;

        Log.debug(
          'Profile adjustment: avoidedMuscles changed to '
          '${merged.map((m) => m.displayName).join(', ')}',
          tag: _tag,
        );
      }
    }

    if (!changed) {
      return profile;
    }

    return profile.copyWith(
      training: training,
    );
  }

  //===========================================================================
  // Option parsing
  //===========================================================================

  List<MuscleGroup>? _parseExcludeMuscles(
    Map<String, dynamic> options,
  ) {
    final raw = options['avoidMuscles'];

    if (raw is! List) {
      return null;
    }

    final muscles = raw
        .map(
          (value) => MuscleGroupExtension.fromValue(
            value.toString(),
          ),
        )
        .toSet()
        .toList();

    return muscles.isEmpty ? null : muscles;
  }

  String? _intensityString(
    Map<String, dynamic> options,
  ) {
    return options['intensity'] as String?;
  }

  //===========================================================================
  // Debug logging
  //===========================================================================

  /// Logs the exercises of one day with their canonical IDs.
  void _logDayExercises({
    required String day,
    required List<Exercise> exercises,
    required String context,
  }) {
    final lines = <String>[
      '',
      'RegenerationService: $context',
      'day: $day',
      'exerciseCount: ${exercises.length}',
      '------------------------------------------------------------',
    ];

    if (exercises.isEmpty) {
      lines.add('  REST / EMPTY');

      Log.debug(
        lines.join('\n'),
        tag: _tag,
      );

      return;
    }

    for (var i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];

      lines.add(
        '  ${i + 1}. ${exercise.name} '
        '[id=${exercise.id}, sets=${exercise.sets}, reps=${exercise.reps}]',
      );
    }

    Log.debug(
      lines.join('\n'),
      tag: _tag,
    );
  }

  /// Logs the set of canonical exercise IDs already used by previous days.
  void _logWeeklyUsedIds({
    required String day,
    required Set<String> weeklyUsedExerciseIds,
    required String context,
  }) {
    final sortedIds = weeklyUsedExerciseIds.toList()..sort();

    Log.debug(
      '''
RegenerationService: $context
currentDay: $day
weeklyUsedExerciseIds.count: ${sortedIds.length}
weeklyUsedExerciseIds:
${sortedIds.isEmpty ? '  <empty>' : sortedIds.map((id) => '  - $id').join('\n')}
''',
      tag: _tag,
    );
  }

  /// Logs duplicate IDs inside a single workout day.
  void _logDuplicateIds({
    required List<Exercise> exercises,
    required String context,
  }) {
    final counts = <String, int>{};
    final names = <String, List<String>>{};

    for (final exercise in exercises) {
      counts.update(
        exercise.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      names
          .putIfAbsent(
            exercise.id,
            () => <String>[],
          )
          .add(
            exercise.name,
          );
    }

    final duplicates = counts.entries
        .where(
          (entry) => entry.value > 1,
        )
        .toList();

    if (duplicates.isEmpty) {
      Log.debug(
        '✅ No duplicate exercise IDs within day. context=$context',
        tag: _tag,
      );

      return;
    }

    final lines = <String>[
      '⚠️ DUPLICATE EXERCISE IDS WITHIN DAY',
      'context: $context',
    ];

    for (final duplicate in duplicates) {
      lines.add(
        '  - id=${duplicate.key}, '
        'count=${duplicate.value}, '
        'names=${names[duplicate.key]!.join(' | ')}',
      );
    }

    Log.warning(
      lines.join('\n'),
      tag: _tag,
    );
  }

  /// Logs duplicate canonical exercise IDs across the complete program.
  void _logWeeklyDuplicateIds({
    required TrainingProgram program,
    required String context,
  }) {
    final occurrences = <String, List<String>>{};
    final names = <String, String>{};

    for (final entry in program.weeklySchedule.entries) {
      final day = entry.key;

      for (final exercise in entry.value) {
        occurrences
            .putIfAbsent(
              exercise.id,
              () => <String>[],
            )
            .add(day);

        names[exercise.id] = exercise.name;
      }
    }

    final duplicates = occurrences.entries
        .where(
          (entry) => entry.value.length > 1,
        )
        .toList();

    if (duplicates.isEmpty) {
      Log.debug(
        '''
✅ NO WEEKLY DUPLICATE EXERCISE IDS
context: $context
''',
        tag: _tag,
      );

      return;
    }

    final lines = <String>[
      '',
      '⚠️⚠️⚠️ WEEKLY DUPLICATE EXERCISE IDS DETECTED',
      'context: $context',
      'programId: ${program.id}',
      '------------------------------------------------------------',
    ];

    for (final duplicate in duplicates) {
      lines.add(
        '  - ${names[duplicate.key]} '
        '[id=${duplicate.key}] '
        'appears ${duplicate.value.length} times: '
        '${duplicate.value.join(', ')}',
      );
    }

    Log.warning(
      lines.join('\n'),
      tag: _tag,
    );
  }

  /// Logs the complete generated/regenerated program.
  void _logProgramSnapshot({
    required TrainingProgram program,
    required String stage,
  }) {
    final lines = <String>[
      '',
      'RegenerationService: Program snapshot [$stage]',
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
          '[id=${exercise.id}, sets=${exercise.sets}, reps=${exercise.reps}]',
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

  //===========================================================================
  // Utilities
  //===========================================================================

  bool _sameMuscleList(
    List<MuscleGroup> first,
    List<MuscleGroup> second,
  ) {
    final firstSet = first.toSet();
    final secondSet = second.toSet();

    return firstSet.length == secondSet.length &&
        firstSet.containsAll(secondSet);
  }
}
