import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/core/services/workout_audio_service.dart';
import 'package:gymgenius/core/services/workout_timer_notification_service.dart';
import 'package:gymgenius/domain/entities/exercise.dart';
import 'package:gymgenius/domain/entities/logged_exercise.dart';
import 'package:gymgenius/domain/entities/logged_set.dart';
import 'package:gymgenius/domain/entities/workout_log.dart';
import 'package:gymgenius/domain/entities/workout_session_settings.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:uuid/uuid.dart';

class WorkoutSessionManager with ChangeNotifier {
  WorkoutSessionManager({
    WorkoutAudioService? audioService,
    WorkoutTimerNotificationService? notificationService,
  })  : _audio = audioService ?? WorkoutAudioService(),
        _notifications =
            notificationService ?? WorkoutTimerNotificationService();

  final WorkoutAudioService _audio;
  final WorkoutTimerNotificationService _notifications;
  final _uuid = const Uuid();

  WorkoutSessionSettings _settings = WorkoutSessionSettings.defaults;
  bool _restEndTimeSoundPlayed = false;

  bool _isWorkoutActive = false;
  DateTime? _workoutStartTime;
  Timer? _sessionDurationTimer;
  Duration _currentWorkoutDuration = Duration.zero;
  String _currentWorkoutName = "";
  String? _currentUserId;
  String? _currentProgramId;
  String? _currentDayKey;

  List<Exercise> _plannedExercises = [];
  List<LoggedExercise> _loggedExercisesData = [];

  int _currentExerciseIndex = -1;

  Timer? _restTimer;
  int _restTimeRemainingSeconds = 0;
  int _currentRestTotalSeconds = 0;
  bool _isResting = false;

  bool _isExerciseTimerActive = false;
  int _exerciseTimerRemainingSeconds = 0;
  String? _exerciseTimerExerciseName;

  // ===========================================================================
  // Getters
  // ===========================================================================

  bool get isWorkoutActive => _isWorkoutActive;

  Duration get currentWorkoutDuration => _currentWorkoutDuration;

  DateTime? get workoutStartTime => _workoutStartTime;

  String get currentWorkoutName => _currentWorkoutName;

  String? get currentProgramId => _currentProgramId;

  String? get currentDayKey => _currentDayKey;

  List<Exercise> get plannedExercises => List.unmodifiable(_plannedExercises);

  List<LoggedExercise> get loggedExercisesData =>
      List.unmodifiable(_loggedExercisesData);

  Exercise? get currentExercise => (_isWorkoutActive &&
          _currentExerciseIndex >= 0 &&
          _currentExerciseIndex < _plannedExercises.length)
      ? _plannedExercises[_currentExerciseIndex]
      : null;

  LoggedExercise? get currentLoggedExerciseData => (_isWorkoutActive &&
          _currentExerciseIndex >= 0 &&
          _currentExerciseIndex < _loggedExercisesData.length)
      ? _loggedExercisesData[_currentExerciseIndex]
      : null;

  int get currentSetIndexForLogging =>
      currentLoggedExerciseData?.sets.length ?? 0;

  int get currentExerciseIndex => _currentExerciseIndex;

  int get totalExercises => _plannedExercises.length;

  int get completedExercisesCount =>
      _loggedExercisesData.where((ex) => ex.completed).length;

  bool get isResting => _isResting;

  int get restTimeRemainingSeconds => _restTimeRemainingSeconds;

  int get currentRestTotalSeconds => _currentRestTotalSeconds;

  bool get isExerciseTimerActive => _isExerciseTimerActive;

  WorkoutAudioService get workoutAudio => _audio;

  // ===========================================================================
  // Initialization
  // ===========================================================================

  Future<void> initialize() async {
    await _notifications.initialize();

    final languageCode = PlatformDispatcher.instance.locale.languageCode;

    await _audio.initializeVoice(
      languageCode: languageCode,
    );
  }

  // ===========================================================================
  // Settings
  // ===========================================================================

  Future<void> applySettings(
    WorkoutSessionSettings settings,
  ) async {
    _settings = settings;

    _audio.applyPreferences(
      sounds: settings.soundsEnabled,
      haptics: settings.hapticsEnabled,
      voice: settings.voiceCountdownEnabled,
    );

    _notifications.enabled = settings.backgroundNotificationsEnabled;
  }

  // ===========================================================================
  // Exercise timer audio
  // ===========================================================================

  Future<void> onExerciseTimerSecond(
    int secondsRemaining,
  ) async {
    await _audio.onTimerSecond(
      secondsRemaining: secondsRemaining,
      kind: WorkoutTimerKind.exercise,
    );
  }

  Future<void> playExerciseTimeUpSound() async {
    await _audio.playExerciseComplete();
  }

  void resetExerciseTimeUpSoundFlag() {
    _audio.resetCountdownState();
  }

  // ===========================================================================
  // Exercise timer snapshot
  // ===========================================================================

  void updateExerciseTimerSnapshot({
    required bool isActive,
    int remainingSeconds = 0,
    String? exerciseName,
  }) {
    _isExerciseTimerActive = isActive;
    _exerciseTimerRemainingSeconds = remainingSeconds;
    _exerciseTimerExerciseName = exerciseName;

    // Keep wakelock synchronized with the current workout state.
    //
    // IMPORTANT:
    // This method may be called while the workout is ending, so
    // _isWorkoutActive MUST already reflect the final state before
    // this synchronization can decide whether to enable or disable
    // the wakelock.
    unawaited(
      _syncWakelock(),
    );

    if (!isActive) {
      unawaited(
        _notifications.cancel(
          id: WorkoutTimerNotificationService.exerciseNotificationId,
        ),
      );
    }
  }

  // ===========================================================================
  // App lifecycle / background notifications
  // ===========================================================================

  Future<void> onAppBackgrounded() async {
    if (!_settings.backgroundNotificationsEnabled || !_isWorkoutActive) {
      return;
    }

    if (_isResting && _restTimeRemainingSeconds > 0) {
      await _notifications.scheduleRestComplete(
        secondsFromNow: _restTimeRemainingSeconds,
        exerciseName: currentExercise?.name,
      );
    }

    if (_isExerciseTimerActive && _exerciseTimerRemainingSeconds > 0) {
      await _notifications.scheduleExerciseComplete(
        secondsFromNow: _exerciseTimerRemainingSeconds,
        exerciseName:
            _exerciseTimerExerciseName ?? currentExercise?.name ?? 'Exercise',
      );
    }
  }

  Future<void> onAppForegrounded() async {
    await _notifications.cancelAll();
  }

  // ===========================================================================
  // Wakelock
  // ===========================================================================

  /// Keeps the device awake only while an active workout session exists.
  ///
  /// Session lifecycle:
  ///
  ///   workout starts
  ///       ↓
  ///   _isWorkoutActive = true
  ///       ↓
  ///   wakelock ON
  ///
  ///   workout ends
  ///       ↓
  ///   _isWorkoutActive = false
  ///       ↓
  ///   wakelock OFF
  Future<void> _syncWakelock() async {
    if (_isWorkoutActive) {
      await _enableWakelock();
    } else {
      await _disableWakelock();
    }
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      Log.error(
        "WorkoutSession: Failed to enable wakelock",
        error: e,
      );
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      Log.error(
        "WorkoutSession: Failed to disable wakelock",
        error: e,
      );
    }
  }

  // ===========================================================================
  // Start workout
  // ===========================================================================

  bool startWorkoutIfNoSession(
    List<Exercise> exercisesForSession, {
    String workoutName = "Workout Session",
    String? userId,
    String? programId,
    String? dayKey,
  }) {
    if (_isWorkoutActive) {
      return false;
    }

    _startWorkoutInternal(
      exercisesForSession,
      workoutName: workoutName,
      userId: userId,
      programId: programId,
      dayKey: dayKey,
    );

    notifyListeners();

    return true;
  }

  void forceStartNewWorkout(
    List<Exercise> exercisesForSession, {
    String workoutName = "Workout Session",
    String? userId,
    String? programId,
    String? dayKey,
  }) {
    if (_isWorkoutActive) {
      _resetSessionState(
        notify: false,
      );
    }

    _startWorkoutInternal(
      exercisesForSession,
      workoutName: workoutName,
      userId: userId,
      programId: programId,
      dayKey: dayKey,
    );

    notifyListeners();
  }

  void _startWorkoutInternal(
    List<Exercise> exercisesForSession, {
    String workoutName = "Workout Session",
    String? userId,
    String? programId,
    String? dayKey,
  }) {
    _isWorkoutActive = true;
    _workoutStartTime = DateTime.now();
    _currentWorkoutDuration = Duration.zero;

    _currentWorkoutName = workoutName;

    _currentUserId = userId;
    _currentProgramId = programId;
    _currentDayKey = dayKey;

    _plannedExercises = List.from(
      exercisesForSession,
    );

    _loggedExercisesData = _plannedExercises.map((ex) {
      return LoggedExercise(
        exerciseId: ex.id,
        name: ex.name,
        targetSets: ex.sets,
        targetReps: ex.reps,
        targetRestSeconds: ex.restSeconds,
        isTimed: ex.isTimed,
        sets: [],
        completed: false,
        rpe: null,
      );
    }).toList();

    _currentExerciseIndex = _plannedExercises.isNotEmpty ? 0 : -1;

    _sessionDurationTimer?.cancel();

    _sessionDurationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!_isWorkoutActive) {
          timer.cancel();
          return;
        }

        _currentWorkoutDuration += const Duration(seconds: 1);

        notifyListeners();
      },
    );

    // Wakelock is enabled once the workout becomes active.
    unawaited(
      _syncWakelock(),
    );

    Log.debug(
      "Workout '$workoutName' started. "
      "CurrentExIndex: $_currentExerciseIndex.",
    );
  }

  // ===========================================================================
  // Log set
  // ===========================================================================

  void logSetForCurrentExercise(
    String reps,
    String weight,
  ) {
    if (currentExercise == null || currentLoggedExerciseData == null) {
      Log.error(
        "No current exercise or logged data available",
      );
      return;
    }

    final currentEx = currentExercise!;
    final currentLog = currentLoggedExerciseData!;

    final parsedReps = int.tryParse(reps) ?? 0;
    final parsedWeight = double.tryParse(weight) ?? 0.0;

    final newSet = LoggedSet(
      setNumber: currentLog.sets.length + 1,
      reps: parsedReps,
      weightKg: parsedWeight,
      loggedAt: DateTime.now(),
    );

    final updatedLog = currentLog.copyWith(
      sets: [
        ...currentLog.sets,
        newSet,
      ],
      completed: currentLog.completed ||
          (currentLog.sets.length + 1 >= currentEx.sets),
    );

    _loggedExercisesData[_currentExerciseIndex] = updatedLog;

    updateExerciseTimerSnapshot(
      isActive: false,
    );

    if (currentEx.restSeconds > 0) {
      if (_isResting) {
        skipRest();
      }

      startRestTimer(
        currentEx.restSeconds,
      );
    } else if (_isResting) {
      skipRest();
    }

    notifyListeners();
  }

  // ===========================================================================
  // Rest timer
  // ===========================================================================

  void startRestTimer(
    int durationSeconds,
  ) {
    if (durationSeconds <= 0) {
      if (_isResting) {
        _isResting = false;

        unawaited(
          _syncWakelock(),
        );

        notifyListeners();
      }

      return;
    }

    _restTimer?.cancel();

    _isResting = true;
    _currentRestTotalSeconds = durationSeconds;
    _restTimeRemainingSeconds = durationSeconds;
    _restEndTimeSoundPlayed = false;

    _audio.resetCountdownState();

    unawaited(
      _syncWakelock(),
    );

    notifyListeners();

    _restTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!_isWorkoutActive || !_isResting) {
          timer.cancel();

          _isResting = false;
          _restTimeRemainingSeconds = 0;

          unawaited(
            _syncWakelock(),
          );

          notifyListeners();

          return;
        }

        if (_restTimeRemainingSeconds > 0) {
          unawaited(
            _audio.onTimerSecond(
              secondsRemaining: _restTimeRemainingSeconds,
              kind: WorkoutTimerKind.rest,
            ),
          );

          _restTimeRemainingSeconds--;
        } else {
          _finishRestTimer(
            playSound: true,
          );
        }

        notifyListeners();
      },
    );
  }

  void adjustRestTimer(
    int deltaSeconds,
  ) {
    if (!_isResting || deltaSeconds == 0) {
      return;
    }

    _restTimeRemainingSeconds = adjustRestSeconds(
      _restTimeRemainingSeconds,
      deltaSeconds,
    );

    if (_restTimeRemainingSeconds > _currentRestTotalSeconds) {
      _currentRestTotalSeconds = _restTimeRemainingSeconds;
    }

    _audio.resetCountdownState();
    _restEndTimeSoundPlayed = false;

    if (_restTimeRemainingSeconds == 0) {
      _finishRestTimer(
        playSound: true,
      );
    }

    notifyListeners();
  }

  void _finishRestTimer({
    required bool playSound,
  }) {
    _restTimer?.cancel();

    if (playSound && _isResting && !_restEndTimeSoundPlayed) {
      unawaited(
        _audio.playRestComplete(),
      );

      _restEndTimeSoundPlayed = true;
    }

    _isResting = false;
    _restTimeRemainingSeconds = 0;

    unawaited(
      _syncWakelock(),
    );

    unawaited(
      _notifications.cancel(
        id: WorkoutTimerNotificationService.restNotificationId,
      ),
    );
  }

  void skipRest() {
    _restTimer?.cancel();

    _isResting = false;
    _restTimeRemainingSeconds = 0;
    _restEndTimeSoundPlayed = true;

    _audio.resetCountdownState();

    unawaited(
      _syncWakelock(),
    );

    unawaited(
      _notifications.cancel(
        id: WorkoutTimerNotificationService.restNotificationId,
      ),
    );

    notifyListeners();
  }

  // ===========================================================================
  // Exercise navigation
  // ===========================================================================

  bool moveToNextExercise() {
    if (!_isWorkoutActive) {
      return false;
    }

    if (currentExercise != null &&
        currentLoggedExerciseData != null &&
        !currentLoggedExerciseData!.completed &&
        currentLoggedExerciseData!.sets.length >= currentExercise!.sets) {
      _loggedExercisesData[_currentExerciseIndex] =
          _loggedExercisesData[_currentExerciseIndex].copyWith(
        completed: true,
      );
    }

    if (_isResting) {
      skipRest();
    }

    updateExerciseTimerSnapshot(
      isActive: false,
    );

    int nextIdx = -1;

    for (int i = _currentExerciseIndex + 1; i < _plannedExercises.length; i++) {
      if (i < _loggedExercisesData.length &&
          !_loggedExercisesData[i].completed) {
        nextIdx = i;
        break;
      }
    }

    if (nextIdx == -1) {
      for (int i = 0; i < _currentExerciseIndex; i++) {
        if (i < _loggedExercisesData.length &&
            !_loggedExercisesData[i].completed) {
          nextIdx = i;
          break;
        }
      }
    }

    if (nextIdx != -1) {
      _currentExerciseIndex = nextIdx;
      _audio.resetCountdownState();
      notifyListeners();

      return true;
    }

    notifyListeners();

    return false;
  }

  bool selectExercise(
    int index,
  ) {
    if (!_isWorkoutActive || index < 0 || index >= _plannedExercises.length) {
      return false;
    }

    _currentExerciseIndex = index;

    _audio.resetCountdownState();

    updateExerciseTimerSnapshot(
      isActive: false,
    );

    if (_isResting) {
      skipRest();
    }

    notifyListeners();

    return true;
  }

  // ===========================================================================
  // End workout
  // ===========================================================================

  WorkoutLog? endWorkout() {
    if (!_isWorkoutActive) {
      return null;
    }

    final endedWorkoutName = _currentWorkoutName;
    final workoutEndTime = DateTime.now();

    _sessionDurationTimer?.cancel();
    _sessionDurationTimer = null;

    _restTimer?.cancel();
    _restTimer = null;

    /*
     * IMPORTANT:
     *
     * Do not rely on updateExerciseTimerSnapshot(false) to disable
     * the wakelock while _isWorkoutActive is still true.
     *
     * _isWorkoutActive must become false before any asynchronous
     * wakelock synchronization can run.
     */
    _isWorkoutActive = false;

    updateExerciseTimerSnapshot(
      isActive: false,
    );

    unawaited(
      _notifications.cancelAll(),
    );

    // At this point _isWorkoutActive is already false, so the
    // synchronization above and this explicit call can only disable
    // the wakelock.
    unawaited(
      _disableWakelock(),
    );

    final totalExercises = _plannedExercises.length;

    final completedExercises = _loggedExercisesData
        .where(
          (e) => e.completed,
        )
        .length;

    final completionScore = totalExercises > 0
        ? (completedExercises / totalExercises * 100).round()
        : 0;

    final workoutLog = WorkoutLog(
      id: _uuid.v4(),
      userId: _currentUserId ?? '',
      programId: _currentProgramId ?? '',
      week: 1,
      day: _currentDayKey ?? 'unknown',
      startedAt: _workoutStartTime ?? workoutEndTime,
      endedAt: workoutEndTime,
      durationSeconds: _currentWorkoutDuration.inSeconds,
      caloriesEstimate: null,
      volume: null,
      averageRPE: null,
      completionScore: completionScore,
      exercises: _loggedExercisesData,
      savedAt: DateTime.now(),
    );

    _resetSessionState(
      notify: false,
    );

    notifyListeners();

    Log.debug(
      "Session '$endedWorkoutName' ended.",
    );

    return workoutLog;
  }

  // ===========================================================================
  // Reset session state
  // ===========================================================================

  void _resetSessionState({
    bool notify = true,
  }) {
    /*
     * IMPORTANT:
     *
     * _isWorkoutActive is set to false FIRST.
     *
     * updateExerciseTimerSnapshot(false) calls _syncWakelock(),
     * so this ordering guarantees that the asynchronous sync sees
     * an inactive workout and disables the wakelock rather than
     * enabling it again.
     */
    _isWorkoutActive = false;

    _sessionDurationTimer?.cancel();
    _sessionDurationTimer = null;

    _restTimer?.cancel();
    _restTimer = null;

    updateExerciseTimerSnapshot(
      isActive: false,
    );

    unawaited(
      _notifications.cancelAll(),
    );

    unawaited(
      _disableWakelock(),
    );

    _workoutStartTime = null;
    _currentWorkoutDuration = Duration.zero;
    _currentWorkoutName = "";

    _currentUserId = null;
    _currentProgramId = null;
    _currentDayKey = null;

    _plannedExercises = [];
    _loggedExercisesData = [];

    _currentExerciseIndex = -1;

    _isResting = false;
    _restTimeRemainingSeconds = 0;
    _currentRestTotalSeconds = 0;
    _restEndTimeSoundPlayed = false;

    _isExerciseTimerActive = false;
    _exerciseTimerRemainingSeconds = 0;
    _exerciseTimerExerciseName = null;

    _audio.resetCountdownState();

    if (notify) {
      notifyListeners();
    }
  }

  // ===========================================================================
  // Dispose
  // ===========================================================================

  @override
  void dispose() {
    _sessionDurationTimer?.cancel();
    _restTimer?.cancel();

    unawaited(
      _audio.dispose(),
    );

    unawaited(
      _disableWakelock(),
    );

    unawaited(
      _notifications.cancelAll(),
    );

    super.dispose();
  }
}
