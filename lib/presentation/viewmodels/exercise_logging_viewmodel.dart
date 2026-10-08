// lib/presentation/viewmodels/exercise_logging_viewmodel.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/domain/entities/exercise.dart';
import 'package:gymgenius/presentation/providers/workout_session_manager.dart';

/// ViewModel for handling exercise logging logic, especially for timed exercises.
class ExerciseLoggingViewModel extends ChangeNotifier {
  final WorkoutSessionManager _sessionManager;
  final Exercise exercise;

  // Form controllers
  final TextEditingController repsController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController minutesController = TextEditingController();
  final TextEditingController secondsController = TextEditingController();

  // Timer state
  Timer? _exerciseTimer;
  int _targetDurationSeconds = 0;
  int _currentExerciseRunDownSeconds = 0;
  bool _isExerciseTimerRunning = false;
  bool _timerPaused = false;
  int _actualDurationCompleted = 0;

  // Getters
  int get currentExerciseRunDownSeconds => _currentExerciseRunDownSeconds;
  int get targetDurationSeconds => _targetDurationSeconds;
  bool get isExerciseTimerRunning => _isExerciseTimerRunning;
  bool get isTimerPaused => _timerPaused;
  int get actualDurationCompleted => _actualDurationCompleted;

  ExerciseLoggingViewModel({
    required WorkoutSessionManager sessionManager,
    required this.exercise,
  }) : _sessionManager = sessionManager {
    _initializeFieldsForCurrentSet();
  }

  void _initializeFieldsForCurrentSet() {
    final loggedData = _sessionManager.currentLoggedExerciseData;

    _stopTimer();
    _isExerciseTimerRunning = false;
    _timerPaused = false;
    _actualDurationCompleted = 0;

    if (loggedData == null || loggedData.completed) {
      repsController.clear();
      weightController.clear();
      minutesController.clear();
      secondsController.clear();

      if (exercise.isTimed) {
        _targetDurationSeconds = exercise.targetDurationSeconds ?? 60;
        minutesController.text = (_targetDurationSeconds ~/ 60).toString();
        secondsController.text =
            (_targetDurationSeconds % 60).toString().padLeft(2, '0');
        _currentExerciseRunDownSeconds = _targetDurationSeconds;
      }
    } else {
      if (exercise.isTimed) {
        _targetDurationSeconds = exercise.targetDurationSeconds ?? 60;
        minutesController.text = (_targetDurationSeconds ~/ 60).toString();
        secondsController.text =
            (_targetDurationSeconds % 60).toString().padLeft(2, '0');
        _currentExerciseRunDownSeconds = _targetDurationSeconds;
        _sessionManager.resetExerciseTimeUpSoundFlag();
      } else {
        repsController.text = _getInitialRepsSuggestion();
        weightController.text = _getInitialWeightSuggestion();
      }
    }
    notifyListeners();
  }

  String _getInitialRepsSuggestion() {
    final repsSuggestion = exercise.reps.trim();
    final repsRangeRegex = RegExp(r'^(\d+)\s*-\s*\d+');
    final singleRepRegex = RegExp(r'^(\d+)$');

    if (repsRangeRegex.hasMatch(repsSuggestion)) {
      return repsRangeRegex.firstMatch(repsSuggestion)!.group(1)!;
    } else if (singleRepRegex.hasMatch(repsSuggestion)) {
      return singleRepRegex.firstMatch(repsSuggestion)!.group(1)!;
    }
    return "";
  }

  String _getInitialWeightSuggestion() {
    // Weighted exercises are pre-filled with the weight suggestion.
    // Bodyweight exercises start empty.
    if (exercise.isBodyweight) return "";

    final weightSuggestion = exercise.weightSuggestion ?? '';

    if (['bodyweight', 'bw', 'n/a', '']
        .contains(weightSuggestion.toLowerCase())) {
      return "";
    }

    final weightRegex = RegExp(r'^(\d+(\.\d+)?)');
    final match = weightRegex.firstMatch(weightSuggestion);
    return match?.group(1) ?? "";
  }

  void startTimerWithAdjustedTime() {
    final minutes = int.tryParse(minutesController.text.trim()) ?? 0;
    final seconds = int.tryParse(secondsController.text.trim()) ?? 0;
    final totalSeconds = (minutes * 60) + seconds;

    if (totalSeconds <= 0) {
      Log.error("Invalid time for timer");
      return;
    }

    _targetDurationSeconds = totalSeconds;
    _currentExerciseRunDownSeconds = _targetDurationSeconds;
    _actualDurationCompleted = 0;
    _isExerciseTimerRunning = true;
    _timerPaused = false;
    _sessionManager.resetExerciseTimeUpSoundFlag();
    _publishExerciseTimerSnapshot();
    notifyListeners();

    _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _onExerciseTimerTick(timer);
    });
  }

  void _publishExerciseTimerSnapshot() {
    _sessionManager.updateExerciseTimerSnapshot(
      isActive: _isExerciseTimerRunning && !_timerPaused,
      remainingSeconds: _currentExerciseRunDownSeconds,
      exerciseName: exercise.name,
    );
  }

  void _onExerciseTimerTick(Timer timer) {
    if (_currentExerciseRunDownSeconds > 0) {
      unawaited(_sessionManager.onExerciseTimerSecond(
        _currentExerciseRunDownSeconds,
      ));
      _currentExerciseRunDownSeconds--;
      _actualDurationCompleted++;
      _publishExerciseTimerSnapshot();
      notifyListeners();
    } else {
      _stopTimerAndLog(isFinished: true);
    }
  }

  void pauseOrResumeTimer() {
    if (_timerPaused) {
      _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _onExerciseTimerTick(timer);
      });
      _timerPaused = false;
    } else {
      _exerciseTimer?.cancel();
      _exerciseTimer = null;
      _timerPaused = true;
    }
    _publishExerciseTimerSnapshot();
    notifyListeners();
  }

  void stopTimerAndLog() {
    if (!_isExerciseTimerRunning && _actualDurationCompleted == 0) {
      return;
    }
    _stopTimerAndLog(isFinished: false);
  }

  void _stopTimerAndLog({bool isFinished = false}) {
    _exerciseTimer?.cancel();
    _exerciseTimer = null;
    _isExerciseTimerRunning = false;
    _timerPaused = false;
    _sessionManager.updateExerciseTimerSnapshot(isActive: false);

    int durationToLog = _actualDurationCompleted;
    if (isFinished) {
      durationToLog = _targetDurationSeconds;
      unawaited(_sessionManager.playExerciseTimeUpSound());
    }

    _sessionManager.logSetForCurrentExercise(
      durationToLog.toString(),
      "0",
    );

    _initializeFieldsForCurrentSet();
  }

  void _stopTimer() {
    _exerciseTimer?.cancel();
    _exerciseTimer = null;
    _isExerciseTimerRunning = false;
    _timerPaused = false;
    _sessionManager.updateExerciseTimerSnapshot(isActive: false);
  }

  String? logSet() {
    if (exercise.isTimed) {
      return "Use the 'Stop & Log Time' button for timed exercises.";
    }

    final reps = repsController.text.trim();
    if (reps.isEmpty || int.tryParse(reps) == null || int.parse(reps) < 0) {
      return "Please enter a valid number of repetitions.";
    }

    // Parse the weight only for weighted exercises.
    // Bodyweight exercises log "0".
    String weightToLog = "0";

    if (!exercise.isBodyweight) {
      final weightInput = weightController.text.trim();

      if (weightInput.isNotEmpty) {
        final parsedWeight = double.tryParse(weightInput);

        if (parsedWeight == null || parsedWeight < 0) {
          return "Weight must be a valid positive number.";
        }

        weightToLog = parsedWeight.toStringAsFixed(2);
      }
    }

    _sessionManager.logSetForCurrentExercise(reps, weightToLog);
    _initializeFieldsForCurrentSet();
    return null;
  }

  String formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  String getTimerButtonText() {
    if (!_isExerciseTimerRunning) {
      return "Start Timer";
    } else if (_timerPaused) {
      return "Resume";
    } else {
      return "Stop & Log Time";
    }
  }

  IconData getTimerButtonIcon() {
    if (!_isExerciseTimerRunning) {
      return Icons.play_arrow_rounded;
    } else if (_timerPaused) {
      return Icons.play_arrow_rounded;
    } else {
      return Icons.stop_rounded;
    }
  }

  @override
  void dispose() {
    Log.debug("ExerciseLoggingViewModel disposed.");
    repsController.dispose();
    weightController.dispose();
    minutesController.dispose();
    secondsController.dispose();
    _exerciseTimer?.cancel();
    _sessionManager.updateExerciseTimerSnapshot(isActive: false);
    super.dispose();
  }
}
