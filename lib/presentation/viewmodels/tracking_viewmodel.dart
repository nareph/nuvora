// lib/presentation/viewmodels/tracking_viewmodel.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/domain/entities/progress_snapshot.dart';
import 'package:gymgenius/domain/entities/training_program.dart';
import 'package:gymgenius/domain/entities/weekly_progress_report.dart';
import 'package:gymgenius/domain/entities/workout_log.dart';
import 'package:gymgenius/domain/enums/progress_period.dart';
import 'package:gymgenius/domain/repositories/progress_repository.dart';
import 'package:gymgenius/domain/repositories/tracking_repository.dart';
import 'package:gymgenius/domain/repositories/user_repository.dart';
import 'package:gymgenius/domain/repositories/workout_repository.dart';
import 'package:table_calendar/table_calendar.dart';

enum TrackingState {
  initial,
  loading,
  loaded,
  error,
}

class TrackingViewModel extends ChangeNotifier {
  final WorkoutRepository _workoutRepository;
  final TrackingRepository _trackingRepository;
  final UserRepository _userRepository;
  final ProgressRepository _progressRepository;

  StreamSubscription? _programSubscription;
  StreamSubscription? _logsSubscription;

  bool _isDisposed = false;

  TrackingViewModel({
    required WorkoutRepository workoutRepository,
    required TrackingRepository trackingRepository,
    required UserRepository userRepository,
    required ProgressRepository progressRepository,
  })  : _workoutRepository = workoutRepository,
        _trackingRepository = trackingRepository,
        _userRepository = userRepository,
        _progressRepository = progressRepository {
    Log.info("TrackingViewModel: Created");

    _focusedDay = DateTime.now();
    _selectedDay = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );

    _loadInitialData();
  }

  // ===========================================================================
  // UI State
  // ===========================================================================

  TrackingState _state = TrackingState.initial;

  TrackingState get state => _state;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  bool _isLoadingDayDetails = false;

  bool get isLoadingDayDetails => _isLoadingDayDetails;

  // ===========================================================================
  // Calendar Data and State
  // ===========================================================================

  late DateTime _focusedDay;

  DateTime get focusedDay => _focusedDay;

  late DateTime _selectedDay;

  DateTime get selectedDay => _selectedDay;

  Map<DateTime, List<String>> _plannedEvents = {};

  Map<DateTime, List<String>> get plannedEvents => _plannedEvents;

  Set<DateTime> _completedWorkoutDates = {};

  Set<DateTime> get completedWorkoutDates => _completedWorkoutDates;

  // ===========================================================================
  // Workout Logs
  // ===========================================================================

  /// Cached workout logs.
  ///
  /// This is the single source of truth for workout logs in this ViewModel.
  List<WorkoutLog> _workoutLogs = [];

  List<WorkoutLog> get workoutLogs => List.unmodifiable(_workoutLogs);

  List<WorkoutLog> _selectedDayLogs = [];

  List<WorkoutLog> get selectedDayLogs => _selectedDayLogs;

  // ===========================================================================
  // Progress Data
  // ===========================================================================

  ProgressSnapshot? _progressSnapshot;

  ProgressSnapshot? get progressSnapshot => _progressSnapshot;

  WeeklyProgressReport? _weeklyReport;

  WeeklyProgressReport? get weeklyReport => _weeklyReport;

  bool _isLoadingProgress = false;

  bool get isLoadingProgress => _isLoadingProgress;

  ProgressPeriod _progressPeriod = ProgressPeriod.weekly;

  ProgressPeriod get progressPeriod => _progressPeriod;

  // ===========================================================================
  // Initialization
  // ===========================================================================

  Future<void> _loadInitialData() async {
    if (_isDisposed) return;

    Log.info("TrackingViewModel: Loading initial data...");

    _setState(TrackingState.loading);

    try {
      await _loadProgramData();

      await _loadWorkoutLogs();

      await _loadProgressData();

      _setupDataListeners();

      if (!_isDisposed) {
        _setState(TrackingState.loaded);
      }

      Log.info(
        "TrackingViewModel: Initial data loaded successfully",
      );
    } catch (error, stackTrace) {
      _handleError(
        error,
        stackTrace,
      );
    }
  }

  // ===========================================================================
  // Program data
  // ===========================================================================

  Future<void> _loadProgramData() async {
    if (_isDisposed) return;

    Log.info(
      "TrackingViewModel: Loading program data...",
    );

    try {
      final user = await _userRepository.getCurrentUser();

      if (user == null) {
        _plannedEvents = {};

        if (!_isDisposed) {
          notifyListeners();
        }

        return;
      }

      final program = await _workoutRepository.getCurrentProgram(
        user.id,
      );

      Log.info(
        "TrackingViewModel: Program found: ${program != null}",
      );

      if (program != null && !program.isExpired) {
        try {
          _generatePlannedEventsForProgram(
            program,
          );

          Log.info(
            "TrackingViewModel: Planned events generated: "
            "${_plannedEvents.length}",
          );
        } catch (e, s) {
          Log.error(
            "TrackingViewModel: Failed to parse program",
            error: e,
            stackTrace: s,
          );

          _plannedEvents = {};
        }
      } else {
        _plannedEvents = {};

        Log.info(
          "TrackingViewModel: No valid program found",
        );
      }

      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (error, stackTrace) {
      Log.error(
        "TrackingViewModel: Error loading program data",
        error: error,
        stackTrace: stackTrace,
      );

      _plannedEvents = {};

      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void _generatePlannedEventsForProgram(
    TrainingProgram program,
  ) {
    if (_isDisposed) return;

    final newEvents = <DateTime, List<String>>{};

    if (program.durationWeeks <= 0 || program.weeklySchedule.isEmpty) {
      _plannedEvents = newEvents;
      return;
    }

    final startDate = program.createdAt;
    final endDate = program.expiresAt;

    var currentDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final daysOfWeek = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    while (!currentDate.isAfter(endDate)) {
      final dayKey = daysOfWeek[currentDate.weekday - 1];

      final exercises = program.weeklySchedule[dayKey];

      if (exercises != null && exercises.isNotEmpty) {
        newEvents[DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
        )] = ['Planned'];
      }

      currentDate = currentDate.add(
        const Duration(days: 1),
      );
    }

    _plannedEvents = newEvents;
  }

  // ===========================================================================
  // Workout logs
  // ===========================================================================

  /// Loads all workout logs from the repository, caches them,
  /// and derives completed dates and selected-day logs.
  ///
  /// This is the single source of truth for workout logs
  /// in this ViewModel.
  Future<void> _loadWorkoutLogs() async {
    if (_isDisposed) return;

    Log.info(
      "TrackingViewModel: Loading workout logs...",
    );

    _isLoadingDayDetails = true;

    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      final user = await _userRepository.getCurrentUser();

      if (user == null) {
        _workoutLogs = [];
        _completedWorkoutDates = {};
        _selectedDayLogs = [];

        if (!_isDisposed) {
          notifyListeners();
        }

        return;
      }

      // Fetch all logs once.
      final logs = await _trackingRepository.getAllLogs();

      _workoutLogs = logs;

      // Compute completed dates using the business rule:
      // WorkoutLog.isCompleted.
      _completedWorkoutDates = logs
          .where(
        (log) => log.isCompleted,
      )
          .map(
        (log) {
          final date = log.savedAt;

          return DateTime(
            date.year,
            date.month,
            date.day,
          );
        },
      ).toSet();

      // Set selected-day logs from the cache.
      _selectedDayLogs = _filterLogsForDay(_selectedDay);

      Log.info(
        "TrackingViewModel: Loaded "
        "${_workoutLogs.length} logs, "
        "${_completedWorkoutDates.length} completed days",
      );
    } catch (e, s) {
      Log.error(
        "TrackingViewModel: Failed to load workout logs",
        error: e,
        stackTrace: s,
      );

      _workoutLogs = [];
      _completedWorkoutDates = {};
      _selectedDayLogs = [];
    } finally {
      if (!_isDisposed) {
        _isLoadingDayDetails = false;
        notifyListeners();
      }
    }
  }

  /// Filters cached logs for a given day.
  List<WorkoutLog> _filterLogsForDay(
    DateTime day,
  ) {
    final normalizedDay = DateTime(
      day.year,
      day.month,
      day.day,
    );

    return _workoutLogs
        .where(
          (log) => isSameDay(
            log.savedAt,
            normalizedDay,
          ),
        )
        .toList();
  }

  // ===========================================================================
  // Progress data
  // ===========================================================================

  Future<void> _loadProgressData() async {
    if (_isDisposed) return;

    _isLoadingProgress = true;

    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      final user = await _userRepository.getCurrentUser();

      if (user == null) {
        _progressSnapshot = null;
        _weeklyReport = null;
        return;
      }

      _progressSnapshot = await _progressRepository.computeSnapshot(
        user.id,
        period: _progressPeriod,
      );

      _weeklyReport = await _progressRepository.computeWeeklyReport(
        user.id,
      );
    } catch (error, stackTrace) {
      Log.error(
        'TrackingViewModel: Error loading progress',
        error: error,
        stackTrace: stackTrace,
      );

      _progressSnapshot = null;
      _weeklyReport = null;
    } finally {
      if (!_isDisposed) {
        _isLoadingProgress = false;
        notifyListeners();
      }
    }
  }

  Future<void> setProgressPeriod(
    ProgressPeriod period,
  ) async {
    if (_isDisposed) return;

    if (_progressPeriod == period) {
      return;
    }

    _progressPeriod = period;

    await _loadProgressData();
  }

  // ===========================================================================
  // Data listeners
  // ===========================================================================

  void _setupDataListeners() {
    if (_isDisposed) return;

    Log.info(
      "TrackingViewModel: Setting up data listeners...",
    );

    _programSubscription?.cancel();
    _logsSubscription?.cancel();

    // Subscribe to workout log stream from TrackingRepository.
    // Whenever a new log is saved, refresh the cached workout
    // logs and recalculate progress.
    _logsSubscription = _trackingRepository.getWorkoutLogsStream().listen(
      (_) {
        if (_isDisposed) return;

        Log.info(
          "TrackingViewModel: Workout logs changed — "
          "refreshing tracking data",
        );

        unawaited(
          _refreshWorkoutLogsFromStream(),
        );
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        Log.error(
          "TrackingViewModel: Workout log stream error",
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// Refreshes cached workout logs and derived state
  /// when the workout log stream fires.
  Future<void> _refreshWorkoutLogsFromStream() async {
    if (_isDisposed) return;

    try {
      final logs = await _trackingRepository.getAllLogs();

      if (_isDisposed) return;

      _workoutLogs = logs;

      _completedWorkoutDates = logs
          .where(
        (log) => log.isCompleted,
      )
          .map(
        (log) {
          final date = log.savedAt;

          return DateTime(
            date.year,
            date.month,
            date.day,
          );
        },
      ).toSet();

      _selectedDayLogs = _filterLogsForDay(_selectedDay);

      Log.info(
        "TrackingViewModel: Stream refresh — "
        "${_workoutLogs.length} logs, "
        "${_completedWorkoutDates.length} completed days",
      );

      // Update UI immediately.
      notifyListeners();

      // Recalculate progress after the cache is updated.
      await _loadProgressData();
    } catch (error, stackTrace) {
      if (_isDisposed) return;

      Log.error(
        "TrackingViewModel: Failed to refresh workout logs from stream",
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // ===========================================================================
  // User interaction
  // ===========================================================================

  void selectDay(
    DateTime day, {
    DateTime? focusedDay,
  }) {
    if (_isDisposed) return;

    final normalizedDay = DateTime(
      day.year,
      day.month,
      day.day,
    );

    Log.info(
      "TrackingViewModel: Selecting day: $normalizedDay",
    );

    if (!isSameDay(
      _selectedDay,
      normalizedDay,
    )) {
      _selectedDay = normalizedDay;
      _focusedDay = focusedDay ?? normalizedDay;

      // Use cached logs — no extra repository call.
      _selectedDayLogs = _filterLogsForDay(normalizedDay);

      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void changeFocusedDay(
    DateTime day,
  ) {
    if (_isDisposed) return;

    _focusedDay = day;

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  List<String> getEventsForDay(
    DateTime day,
  ) {
    if (_isDisposed) return [];

    final dateOnly = DateTime(
      day.year,
      day.month,
      day.day,
    );

    if (_completedWorkoutDates.contains(
      dateOnly,
    )) {
      return ['Completed'];
    }

    if (_plannedEvents[dateOnly]?.isNotEmpty ?? false) {
      return ['Planned'];
    }

    return [];
  }

  // ===========================================================================
  // Error and state management
  // ===========================================================================

  void _handleError(
    Object error,
    StackTrace stack,
  ) {
    if (_isDisposed) return;

    Log.error(
      "TrackingViewModel Error",
      error: error,
      stackTrace: stack,
    );

    _errorMessage = "Failed to load tracking data.";

    _setState(
      TrackingState.error,
    );
  }

  void _setState(
    TrackingState newState,
  ) {
    if (_isDisposed) return;

    Log.info(
      "TrackingViewModel: State changing "
      "from $_state to $newState",
    );

    _state = newState;

    notifyListeners();
  }

  // ===========================================================================
  // Refresh
  // ===========================================================================

  Future<void> refresh() async {
    if (_isDisposed) return;

    Log.info(
      "TrackingViewModel: Manual refresh requested",
    );

    await _loadInitialData();
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  void dispose() {
    Log.info(
      "TrackingViewModel: Disposing",
    );

    _isDisposed = true;

    _programSubscription?.cancel();
    _logsSubscription?.cancel();

    super.dispose();
  }
}
