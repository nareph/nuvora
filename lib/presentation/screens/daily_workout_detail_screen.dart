// lib/presentation/screens/daily_workout_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/domain/entities/exercise.dart';
import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/presentation/providers/workout_session_manager.dart';
import 'package:gymgenius/presentation/screens/active_workout_session_screen.dart';
import 'package:gymgenius/presentation/widgets/exercise/exercise_media.dart';
import 'package:provider/provider.dart';

class DailyWorkoutDetailScreen extends StatefulWidget {
  final String dayTitle;
  final List<Exercise> initialExercises;
  final String? programIdForLog;
  final String dayKeyForLog;
  final HealthProfile healthProfile;

  const DailyWorkoutDetailScreen({
    super.key,
    required this.dayTitle,
    required this.initialExercises,
    this.programIdForLog,
    required this.dayKeyForLog,
    required this.healthProfile,
  });

  @override
  State<DailyWorkoutDetailScreen> createState() =>
      _DailyWorkoutDetailScreenState();
}

class _DailyWorkoutDetailScreenState extends State<DailyWorkoutDetailScreen> {
  late List<Exercise> _exercises;

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.initialExercises);
  }

  // ==========================================================================
  // Exercise details dialog — now with the animated GIF at the top.
  // ==========================================================================
  void _showExerciseDetails(BuildContext context, Exercise exercise) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final colorScheme = Theme.of(dialogCtx).colorScheme;
        final textTheme = Theme.of(dialogCtx).textTheme;

        return AlertDialog(
          title: Text(exercise.name),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ NEW: animated GIF preview
                ExerciseMediaGif(
                  exerciseId: exercise.id,
                  maxHeight: 220,
                ),
                const SizedBox(height: 16),

                // Sets / reps summary
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prescription',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${exercise.sets} sets × ${exercise.reps}'
                        '${exercise.weightSuggestion != null && exercise.weightSuggestion!.isNotEmpty && exercise.weightSuggestion!.toLowerCase() != 'bodyweight' ? ' @ ${exercise.weightSuggestion}' : ''}',
                        style: textTheme.bodyMedium,
                      ),
                      Text(
                        'Rest: ${exercise.restSeconds}s',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  exercise.description.replaceAll("\\n", "\n\n"),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(dialogCtx).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final workoutManager = context.read<WorkoutSessionManager>();
    final sessionName =
        widget.dayTitle.replaceFirst(" Workout Details", " Workout");

    return Scaffold(
      appBar: AppBar(title: Text(widget.dayTitle)),
      body: Column(
        children: [
          Expanded(
            child: _exercises.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_outlined,
                              size: 64,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6)),
                          const SizedBox(height: 20),
                          Text(
                            "No exercises scheduled.",
                            style: textTheme.titleLarge
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Enjoy your rest day!",
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    itemCount: _exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _exercises[index];
                      return _ExerciseListTile(
                        index: index,
                        exercise: exercise,
                        onTap: () => _showExerciseDetails(context, exercise),
                      );
                    },
                  ),
          ),
          if (_exercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_fill_rounded, size: 24),
                label: const Text("Start This Workout"),
                onPressed: () {
                  if (workoutManager.isWorkoutActive) {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text("Workout in Progress"),
                        content: const Text(
                            "Another workout session is active. What would you like to do?"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ActiveWorkoutSessionScreen()),
                              );
                            },
                            child: Text("Resume Current",
                                style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                              workoutManager.forceStartNewWorkout(
                                _exercises,
                                workoutName: sessionName,
                                programId: widget.programIdForLog,
                                dayKey: widget.dayKeyForLog,
                              );
                              if (workoutManager.isWorkoutActive) {
                                Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ActiveWorkoutSessionScreen()));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: const Text(
                                            "Failed to start workout."),
                                        backgroundColor:
                                            theme.colorScheme.error));
                              }
                            },
                            child: Text("End & Start New",
                                style:
                                    TextStyle(color: theme.colorScheme.error)),
                          ),
                          TextButton(
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                              child: const Text("Cancel")),
                        ],
                      ),
                    );
                  } else {
                    final started = workoutManager.startWorkoutIfNoSession(
                      _exercises,
                      workoutName: sessionName,
                      programId: widget.programIdForLog,
                      dayKey: widget.dayKeyForLog,
                    );
                    if (started) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ActiveWorkoutSessionScreen()));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text("Failed to start workout."),
                          backgroundColor: theme.colorScheme.error));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Exercise list tile with thumbnail
// ============================================================================

class _ExerciseListTile extends StatelessWidget {
  final int index;
  final Exercise exercise;
  final VoidCallback onTap;

  const _ExerciseListTile({
    required this.index,
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final weightPart = exercise.weightSuggestion != null &&
            exercise.weightSuggestion!.isNotEmpty &&
            exercise.weightSuggestion!.toLowerCase() != 'bodyweight'
        ? ' @ ${exercise.weightSuggestion}'
        : (exercise.isBodyweight ? ' (Bodyweight)' : '');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Order number
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Thumbnail (image + GIF badge)
              ExerciseMediaThumbnail(
                exerciseId: exercise.id,
                size: 56,
              ),
              const SizedBox(width: 12),

              // Text block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exercise.sets} sets × ${exercise.reps}$weightPart',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Rest: ${exercise.restSeconds}s',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.info_outline_rounded,
                color: colorScheme.secondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
