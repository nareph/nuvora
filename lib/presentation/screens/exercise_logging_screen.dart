// lib/presentation/screens/exercise_logging_screen.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/domain/entities/exercise.dart';
import 'package:gymgenius/domain/entities/logged_exercise.dart';
import 'package:gymgenius/presentation/providers/workout_session_manager.dart';
import 'package:gymgenius/presentation/viewmodels/exercise_logging_viewmodel.dart';
import 'package:gymgenius/presentation/widgets/exercise/exercise_media.dart';
import 'package:gymgenius/presentation/widgets/workout/workout_rest_timer_controls.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ExerciseLoggingScreen extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onExerciseCompleted;

  const ExerciseLoggingScreen({
    super.key,
    required this.exercise,
    required this.onExerciseCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ExerciseLoggingViewModel(
        sessionManager: context.read<WorkoutSessionManager>(),
        exercise: exercise,
      ),
      child: const ExerciseLoggingView(),
    );
  }
}

class ExerciseLoggingView extends StatelessWidget {
  const ExerciseLoggingView({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WorkoutSessionManager>();
    final viewModel = context.read<ExerciseLoggingViewModel>();
    final currentLoggedData = manager.currentLoggedExerciseData;

    // Redirect if no workout active or exercise mismatch
    if (!manager.isWorkoutActive ||
        currentLoggedData == null ||
        currentLoggedData.exerciseId != viewModel.exercise.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Check if exercise is completed
    if (currentLoggedData.completed) {
      final currentExerciseIndex = manager.loggedExercisesData
          .indexWhere((data) => data.exerciseId == viewModel.exercise.id);
      final isLastExercise =
          currentExerciseIndex == manager.plannedExercises.length - 1;

      if (manager.isResting) {
        return _buildRestAfterCompletionView(
          context,
          viewModel.exercise.name,
          currentLoggedData,
          manager,
          isLastExercise,
        );
      }

      return _buildCompletedView(
        context,
        viewModel.exercise.name,
        currentLoggedData,
        isLastExercise,
      );
    }

    // Main logging UI
    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.exercise.name),
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // animated GIF preview so the user can see
              // the movement they are about to perform.
              ExerciseMediaGif(
                exerciseId: viewModel.exercise.id,
                maxHeight: 200,
              ),
              SizedBox(height: 16),

              _SetHeader(exercise: viewModel.exercise),
              if (manager.isResting)
                _RestTimerView(manager: manager)
              else ...[
                const SizedBox(height: 20),
                if (viewModel.exercise.isTimed)
                  _TimedExerciseForm()
                else
                  _RepBasedExerciseForm(),
              ],
              if (currentLoggedData.sets.isNotEmpty)
                _LoggedSetsList(loggedData: currentLoggedData),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildRestAfterCompletionView(
  BuildContext context,
  String exerciseName,
  LoggedExercise loggedData,
  WorkoutSessionManager manager,
  bool isLastExercise,
) {
  final viewModel = context.read<ExerciseLoggingViewModel>();
  final theme = Theme.of(context);
  final urgent = manager.restTimeRemainingSeconds > 0 &&
      manager.restTimeRemainingSeconds <= 3;

  return Scaffold(
    appBar: AppBar(title: Text(exerciseName), automaticallyImplyLeading: false),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 60, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              "$exerciseName Complete!",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "${loggedData.sets.length} sets logged.",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 16.0),
              color: urgent
                  ? theme.colorScheme.errorContainer.withAlpha(120)
                  : theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      isLastExercise
                          ? (urgent
                              ? "REST — FINISH STRONG"
                              : "REST BEFORE FINISHING")
                          : (urgent
                              ? "REST — NEXT EXERCISE SOON"
                              : "REST BEFORE NEXT EXERCISE"),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: urgent ? Colors.orange.shade900 : null),
                    ),
                    const SizedBox(height: 12),
                    WorkoutRestTimerControls(
                      manager: manager,
                      formatDuration: viewModel.formatDuration,
                      showSkip: true,
                      onContinue: () {
                        manager.skipRest();
                        Navigator.pop(context);
                      },
                      continueLabel: isLastExercise
                          ? 'Finish Workout'
                          : 'Continue Workout',
                      continueIcon: isLastExercise
                          ? Icons.celebration_rounded
                          : Icons.arrow_forward_ios_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildCompletedView(
  BuildContext context,
  String exerciseName,
  LoggedExercise loggedData,
  bool isLastExercise,
) {
  return Scaffold(
    appBar: AppBar(title: Text(exerciseName), automaticallyImplyLeading: false),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLastExercise
                  ? Icons.celebration_rounded
                  : Icons.check_circle_outline_rounded,
              size: 80,
              color: isLastExercise ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              isLastExercise ? "Workout Complete!" : "$exerciseName Complete!",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isLastExercise
                  ? "All exercises completed! Great job!"
                  : "${loggedData.sets.length} sets logged.",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              icon: Icon(
                isLastExercise
                    ? Icons.home_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 18,
              ),
              label:
                  Text(isLastExercise ? "Finish Workout" : "Continue Workout"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SetHeader extends StatelessWidget {
  final Exercise exercise;

  const _SetHeader({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WorkoutSessionManager>();
    final currentLoggedData = manager.currentLoggedExerciseData;
    final setNumber =
        currentLoggedData != null ? currentLoggedData.sets.length + 1 : 1;
    final totalSets = exercise.sets;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              setNumber <= totalSets
                  ? "Set $setNumber of $totalSets"
                  : "Extra Set",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              exercise.isTimed
                  ? "Target: ${exercise.targetDurationSeconds ?? 60}s"
                  : "Target: ${exercise.reps} reps",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!exercise.isBodyweight && !exercise.isTimed)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Suggested weight: ${exercise.weightSuggestion ?? 'N/A'}",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RestTimerView extends StatelessWidget {
  final WorkoutSessionManager manager;

  const _RestTimerView({required this.manager});

  bool _isUrgent(int seconds) => seconds > 0 && seconds <= 3;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ExerciseLoggingViewModel>();
    final theme = Theme.of(context);
    final urgent = _isUrgent(manager.restTimeRemainingSeconds);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      color: urgent
          ? theme.colorScheme.errorContainer.withAlpha(120)
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              urgent ? 'REST — GET READY' : 'REST',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: urgent ? Colors.orange.shade900 : null,
              ),
            ),
            const SizedBox(height: 12),
            WorkoutRestTimerControls(
              manager: manager,
              formatDuration: viewModel.formatDuration,
              showSkip: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimedExerciseForm extends StatelessWidget {
  bool _isUrgent(int seconds) => seconds > 0 && seconds <= 3;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExerciseLoggingViewModel>();
    final theme = Theme.of(context);
    final urgent = viewModel.isExerciseTimerRunning &&
        _isUrgent(viewModel.currentExerciseRunDownSeconds);
    final timerColor = viewModel.isExerciseTimerRunning
        ? (urgent ? Colors.red : theme.colorScheme.primary)
        : theme.colorScheme.onSurface;

    return Column(
      children: [
        if (!viewModel.isExerciseTimerRunning || viewModel.isTimerPaused) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Adjust target time before starting",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: viewModel.minutesController,
                          decoration: const InputDecoration(
                            labelText: "Minutes",
                            border: OutlineInputBorder(),
                            suffixText: "min",
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(":", style: TextStyle(fontSize: 28)),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: viewModel.secondsController,
                          decoration: const InputDecoration(
                            labelText: "Seconds",
                            border: OutlineInputBorder(),
                            suffixText: "sec",
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Target time: ${viewModel.formatDuration(viewModel.targetDurationSeconds)}",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  viewModel.isExerciseTimerRunning
                      ? "Time remaining"
                      : "Ready to start",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Text(
                  viewModel
                      .formatDuration(viewModel.currentExerciseRunDownSeconds),
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: timerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 64,
                  ),
                ),
                const SizedBox(height: 16),
                if (viewModel.isExerciseTimerRunning)
                  LinearProgressIndicator(
                    value: viewModel.currentExerciseRunDownSeconds > 0
                        ? viewModel.currentExerciseRunDownSeconds /
                            (viewModel.targetDurationSeconds > 0
                                ? viewModel.targetDurationSeconds.toDouble()
                                : 1.0)
                        : 0,
                    color: timerColor,
                    minHeight: urgent ? 10 : 8,
                  ),
                if (viewModel.isExerciseTimerRunning ||
                    viewModel.actualDurationCompleted > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      "Time completed: ${viewModel.formatDuration(viewModel.actualDurationCompleted)}",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            if (viewModel.isExerciseTimerRunning) ...[
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(
                    viewModel.isTimerPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 24,
                  ),
                  label: Text(
                    viewModel.isTimerPaused ? "Resume" : "Pause",
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: viewModel.isTimerPaused
                        ? Colors.orange
                        : Colors.blueGrey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: viewModel.pauseOrResumeTimer,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: viewModel.isExerciseTimerRunning ? 1 : 2,
              child: ElevatedButton.icon(
                icon: Icon(
                  viewModel.getTimerButtonIcon(),
                  size: 28,
                ),
                label: Text(
                  viewModel.getTimerButtonText(),
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: viewModel.isExerciseTimerRunning
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onPressed: () {
                  if (!viewModel.isExerciseTimerRunning) {
                    viewModel.startTimerWithAdjustedTime();
                  } else {
                    if (viewModel.isTimerPaused) {
                      viewModel.pauseOrResumeTimer();
                    } else {
                      viewModel.stopTimerAndLog();
                    }
                  }
                },
              ),
            ),
          ],
        ),
        if (!viewModel.isExerciseTimerRunning)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Adjust target time, then start timer. "
                      "Completed time will be automatically logged.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RepBasedExerciseForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ExerciseLoggingViewModel>();

    return Column(
      children: [
        if (!viewModel.exercise.isBodyweight) ...[
          TextFormField(
            controller: viewModel.weightController,
            decoration: InputDecoration(
              labelText: "Weight (kg)",
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.fitness_center),
              helperText:
                  "Suggested: ${viewModel.exercise.weightSuggestion ?? 'N/A'}",
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: viewModel.repsController,
          decoration: InputDecoration(
            labelText: "Reps",
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.repeat),
            helperText: "Target: ${viewModel.exercise.reps}",
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline_rounded, size: 28),
          label: const Text("Log Set", style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
          onPressed: () {
            final error = viewModel.logSet();
            if (error != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error), backgroundColor: Colors.red),
              );
            }
          },
        ),
      ],
    );
  }
}

class _LoggedSetsList extends StatelessWidget {
  final LoggedExercise loggedData;

  const _LoggedSetsList({required this.loggedData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Logged Sets:", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: loggedData.sets.length,
            itemBuilder: (ctx, index) {
              final loggedSet = loggedData.sets[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      "${loggedSet.setNumber}",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    loggedData.isTimed
                        ? "Time: ${loggedSet.reps}s"
                        : "Reps: ${loggedSet.reps}, Weight: ${loggedSet.weightKg}kg",
                  ),
                  trailing: Text(
                    DateFormat.jm().format(loggedSet.loggedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
