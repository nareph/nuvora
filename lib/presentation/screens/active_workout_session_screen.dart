// lib/presentation/screens/active_workout_session_screen.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/domain/entities/exercise.dart';
import 'package:gymgenius/domain/repositories/workout_repository.dart';
import 'package:gymgenius/presentation/providers/workout_session_manager.dart';
import 'package:gymgenius/presentation/viewmodels/active_workout_viewmodel.dart';
import 'package:gymgenius/presentation/widgets/exercise/exercise_media.dart';
import 'package:provider/provider.dart';

class ActiveWorkoutSessionScreen extends StatelessWidget {
  const ActiveWorkoutSessionScreen({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return "$hours:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  bool _allExercisesEffectivelyCompleted(WorkoutSessionManager manager) {
    if (!manager.isWorkoutActive || manager.plannedExercises.isEmpty) {
      return false;
    }
    if (manager.loggedExercisesData.length < manager.plannedExercises.length) {
      return false;
    }
    return manager.loggedExercisesData.every((exData) => exData.completed);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ActiveWorkoutViewModel(
      sessionManager: context.read<WorkoutSessionManager>(),
      workoutRepository: context.read<WorkoutRepository>(),
      context: context,
    );

    return Consumer<WorkoutSessionManager>(
      builder: (consumerContext, manager, child) {
        if (!manager.isWorkoutActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (consumerContext.mounted) {
              Navigator.of(consumerContext).popUntil((route) => route.isFirst);
            }
          });
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Finalizing workout session..."),
                ],
              ),
            ),
          );
        }

        if (manager.plannedExercises.isEmpty) {
          return _buildEmptyWorkoutView(consumerContext, viewModel);
        }

        return _buildActiveWorkoutView(consumerContext, manager, viewModel);
      },
    );
  }

  Widget _buildActiveWorkoutView(
    BuildContext context,
    WorkoutSessionManager manager,
    ActiveWorkoutViewModel viewModel,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    int visuallyHighlightedIndex =
        manager.loggedExercisesData.indexWhere((ex) => !ex.completed);
    if (visuallyHighlightedIndex == -1) {
      visuallyHighlightedIndex = manager.completedExercisesCount;
    }

    final bool allDone = _allExercisesEffectivelyCompleted(manager);

    String nextUpText;
    if (allDone) {
      nextUpText = "Workout Complete! Press Finish.";
    } else if (visuallyHighlightedIndex < manager.plannedExercises.length) {
      nextUpText =
          "Next Up: ${manager.plannedExercises[visuallyHighlightedIndex].name}";
    } else {
      nextUpText = "Ready to log!";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(manager.currentWorkoutName),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                _formatDuration(manager.currentWorkoutDuration),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            color: colorScheme.surfaceContainerHighest.withAlpha(77),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(nextUpText,
                        style: textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis)),
                Text(
                    "${manager.completedExercisesCount} / ${manager.totalExercises} done"),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: manager.plannedExercises.length,
              itemBuilder: (listContext, index) {
                final plannedExercise = manager.plannedExercises[index];
                final loggedData = manager.loggedExercisesData[index];
                final isCompleted = loggedData.completed;
                final isCurrent = index == visuallyHighlightedIndex && !allDone;

                return ExerciseTile(
                  exercise: plannedExercise,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  index: index,
                  onTap: () => viewModel.navigateToLogExercise(index),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 20.0),
            child: _EndWorkoutButton(
              allExercisesCompleted: allDone,
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (dialogContext) =>
                      _buildEndWorkoutDialog(dialogContext, allDone),
                ).then((confirmed) {
                  if (confirmed == true) {
                    viewModel.endWorkout();
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWorkoutView(
      BuildContext context, ActiveWorkoutViewModel viewModel) {
    return Scaffold(
      appBar: AppBar(title: const Text("Empty Workout")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.playlist_remove_rounded,
                size: 60, color: Colors.orangeAccent),
            const SizedBox(height: 20),
            Text("This workout has no exercises.",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text("End Empty Session"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: viewModel.endWorkout,
            ),
          ],
        ),
      ),
    );
  }

  AlertDialog _buildEndWorkoutDialog(BuildContext context, bool allDone) {
    return AlertDialog(
      title: const Text('Confirm End Workout'),
      content: Text(allDone
          ? 'Well done! Ready to save this session?'
          : 'Are you sure you want to end the workout early? Any completed exercises will be saved.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            allDone ? 'Finish & Save' : 'End Early',
            style: TextStyle(
                color: allDone
                    ? Colors.green.shade700
                    : Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}

class _EndWorkoutButton extends StatelessWidget {
  final bool allExercisesCompleted;
  final VoidCallback onPressed;

  const _EndWorkoutButton(
      {required this.allExercisesCompleted, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(allExercisesCompleted
          ? Icons.save_alt_rounded
          : Icons.stop_circle_outlined),
      label: Text(allExercisesCompleted
          ? "FINISH & SAVE WORKOUT"
          : "END WORKOUT EARLY"),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: allExercisesCompleted
            ? Colors.green.shade600
            : Theme.of(context).colorScheme.errorContainer,
        foregroundColor: allExercisesCompleted
            ? Colors.white
            : Theme.of(context).colorScheme.onErrorContainer,
        minimumSize: const Size(double.infinity, 52),
      ),
    );
  }
}

class ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final bool isCompleted;
  final bool isCurrent;
  final int index;
  final VoidCallback onTap;

  const ExerciseTile({
    super.key,
    required this.exercise,
    required this.isCompleted,
    required this.isCurrent,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String setsRepsInfo = "${exercise.sets} sets × ${exercise.reps} reps";
    if (exercise.weightSuggestion != null &&
        exercise.weightSuggestion!.isNotEmpty &&
        !['n/a', 'bodyweight']
            .contains(exercise.weightSuggestion!.toLowerCase())) {
      setsRepsInfo += " @ ${exercise.weightSuggestion}kg";
    } else if (exercise.isBodyweight) {
      setsRepsInfo += " (Bodyweight)";
    }

    return Card(
      elevation: isCurrent ? 4.0 : (isCompleted ? 0.5 : 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(
          color: isCompleted
              ? Colors.green.withAlpha(153)
              : (isCurrent
                  ? colorScheme.primary.withAlpha(204)
                  : colorScheme.outlineVariant.withAlpha(100)),
          width: isCurrent ? 2.0 : 1.2,
        ),
      ),
      color: isCompleted ? colorScheme.surfaceContainer.withAlpha(100) : null,
      child: InkWell(
        onTap: isCompleted ? null : onTap,
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // ── Thumbnail with status badge overlay ─────────────
              _ExerciseTileThumbnail(
                exerciseId: exercise.id,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                index: index,
              ),
              const SizedBox(width: 12),

              // ── Text block ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted
                            ? colorScheme.onSurfaceVariant.withAlpha(153)
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      setsRepsInfo,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              // ── Trailing icon ───────────────────────────────────
              if (!isCompleted)
                Icon(
                  isCurrent
                      ? Icons.edit_note_rounded
                      : Icons.play_circle_outline_rounded,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Thumbnail with a small status badge in the bottom-right corner.
// ============================================================================

class _ExerciseTileThumbnail extends StatelessWidget {
  final String exerciseId;
  final bool isCompleted;
  final bool isCurrent;
  final int index;

  const _ExerciseTileThumbnail({
    required this.exerciseId,
    required this.isCompleted,
    required this.isCurrent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          // The image itself (with GIF badge handled internally by
          // ExerciseMediaThumbnail).
          ExerciseMediaThumbnail(
            exerciseId: exerciseId,
            size: 56,
          ),

          // Status badge — replaces the GIF badge position when the
          // exercise is current / completed, so the two badges never
          // overlap.
          Positioned(
            left: 2,
            top: 2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.shade600
                    : (isCurrent
                        ? colorScheme.primary
                        : colorScheme.secondaryContainer),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surface,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    )
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isCurrent
                            ? colorScheme.onPrimary
                            : colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
