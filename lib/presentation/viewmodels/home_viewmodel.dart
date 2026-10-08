// lib/presentation/viewmodels/home_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/domain/entities/daily_checkin.dart';
import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/entities/training_program.dart';
import 'package:gymgenius/domain/repositories/coach_repository.dart';
import 'package:gymgenius/domain/repositories/health_platform_repository.dart';
import 'package:gymgenius/domain/repositories/health_repository.dart';
import 'package:gymgenius/domain/repositories/progress_repository.dart';
import 'package:gymgenius/domain/repositories/recovery_repository.dart';
import 'package:gymgenius/domain/repositories/user_repository.dart';
import 'package:gymgenius/domain/entities/health_platform_snapshot.dart';
import 'package:gymgenius/domain/entities/progress_snapshot.dart';
import 'package:gymgenius/engines/ai_coach/ai_coach_engine.dart';
import 'package:gymgenius/engines/ai_coach/models/coach_response.dart';
import 'package:gymgenius/engines/decision_engine/decision_engine.dart';
import 'package:gymgenius/engines/decision_engine/models/daily_plan.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercises/catalog/exercise_catalog.dart';
import 'package:gymgenius/engines/workout_engine/workout_engine.dart';
import 'package:gymgenius/presentation/screens/recovery/daily_checkin_screen.dart';
import 'package:gymgenius/presentation/widgets/regeneration/regeneration_options_sheet.dart';

enum HomeState { initial, loading, loaded, error }

class HomeViewModel extends ChangeNotifier {
  final WorkoutEngine _workoutEngine;
  final UserRepository _userRepository;
  final HealthRepository _healthRepository;
  final DecisionEngine _decisionEngine;
  final RecoveryRepository _recoveryRepository;
  final ProgressRepository _progressRepository;
  final AICoachEngine _aiCoachEngine;
  final CoachRepository _coachRepository;
  final HealthPlatformRepository _healthPlatformRepository;

  BuildContext? _context;

  HomeViewModel({
    required WorkoutEngine workoutEngine,
    required UserRepository userRepository,
    required HealthRepository healthRepository,
    required DecisionEngine decisionEngine,
    required RecoveryRepository recoveryRepository,
    required ProgressRepository progressRepository,
    required AICoachEngine aiCoachEngine,
    required CoachRepository coachRepository,
    required HealthPlatformRepository healthPlatformRepository,
  })  : _workoutEngine = workoutEngine,
        _userRepository = userRepository,
        _healthRepository = healthRepository,
        _decisionEngine = decisionEngine,
        _recoveryRepository = recoveryRepository,
        _progressRepository = progressRepository,
        _aiCoachEngine = aiCoachEngine,
        _coachRepository = coachRepository,
        _healthPlatformRepository = healthPlatformRepository {
    Log.info('HomeViewModel: Created');
    _loadData();
  }

  // =========================================================================
  // State
  // =========================================================================

  HomeState _state = HomeState.initial;
  HomeState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isGeneratingProgram = false;
  bool get isGeneratingProgram => _isGeneratingProgram;

  bool _autoRefreshAttempted = false;

  // =========================================================================
  // Health Profile
  // =========================================================================

  HealthProfile? _healthProfile;
  HealthProfile? get healthProfile => _healthProfile;

  bool _isProfileComplete = false;
  bool get isProfileComplete => _isProfileComplete;

  // =========================================================================
  // Current Program
  // =========================================================================

  TrainingProgram? _currentProgram;
  TrainingProgram? get currentProgram => _currentProgram;

  // =========================================================================
  // Daily Plan
  // =========================================================================

  DailyPlan? _dailyPlan;
  DailyPlan? get dailyPlan => _dailyPlan;

  CoachResponse? _dailyCoaching;
  CoachResponse? get dailyCoaching => _dailyCoaching;

  bool _isLoadingCoaching = false;
  bool get isLoadingCoaching => _isLoadingCoaching;

  // =========================================================================
  // Data loading
  // =========================================================================

  Future<void> _loadData() async {
    Log.info('HomeViewModel: Loading data...');

    // ✅ NEW: lazy-load the exercise catalog BEFORE anything else.
    // Home renders exercise thumbnails via ProgramCard, so we need the
    // catalog ready before the first build.
    await ExerciseCatalog.ensureLoaded();

    _state = HomeState.loading;
    notifyListeners();

    try {
      final user = await _userRepository.getCurrentUser();

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final healthProfile = await _healthRepository.getCurrentProfile();

      _healthProfile = healthProfile;

      _isProfileComplete = healthProfile != null && healthProfile.isComplete;

      final program = await _workoutEngine.getCurrentProgram();

      _currentProgram = program;

      // Recovery is data-driven.
      //
      // If there is no check-in for today,
      // checkIn stays null and the DecisionEngine
      // MUST NOT create a RecoveryStatus.
      DailyCheckIn? checkIn = await _recoveryRepository.getDailyCheckIn(
        user.id,
        DateTime.now(),
      );

      ProgressSnapshot? progressSnapshot;

      try {
        progressSnapshot = await _progressRepository.computeSnapshot(user.id);
      } catch (e, s) {
        Log.error(
          'HomeViewModel: Progress snapshot failed',
          error: e,
          stackTrace: s,
        );

        progressSnapshot = null;
      }

      HealthPlatformSnapshot? healthPlatformSnapshot;

      try {
        healthPlatformSnapshot =
            await _healthPlatformRepository.computeSnapshot(
          user.id,
          weightKg: healthProfile?.currentWeightKg,
          isTrainingDay: program != null,
        );
      } catch (e, s) {
        Log.error(
          'HomeViewModel: Health platform snapshot failed',
          error: e,
          stackTrace: s,
        );

        healthPlatformSnapshot = null;
      }

      if (program == null || healthProfile == null) {
        _dailyPlan = null;
      } else {
        _dailyPlan = await _decisionEngine.buildDailyPlanAndPersist(
          program,
          healthProfile,
          checkIn: checkIn,
          progressSnapshot: progressSnapshot,
          healthPlatformSnapshot: healthPlatformSnapshot,
        );

        if (await _maybeAutoRefreshProgram(
          program: program,
          profile: healthProfile,
          plan: _dailyPlan!,
        )) {
          return;
        }
      }

      Log.info('HomeViewModel: Profile complete: $_isProfileComplete');
      Log.info('HomeViewModel: Program found: ${_currentProgram != null}');
      Log.info('HomeViewModel: DailyPlan loaded: ${_dailyPlan != null}');
      Log.info(
          'HomeViewModel: Recovery status: ${_dailyPlan?.recoveryStatus != null}');

      _state = HomeState.loaded;
      notifyListeners();

      if (_dailyPlan != null) {
        await _loadDailyCoaching(user.id, _dailyPlan!);
      } else {
        _dailyCoaching = null;
      }
    } catch (error, stackTrace) {
      Log.error(
        'HomeViewModel: Error loading data',
        error: error,
        stackTrace: stackTrace,
      );

      _errorMessage = error.toString();
      _state = HomeState.error;
      notifyListeners();
    }
  }

  // =========================================================================
  // Auto refresh
  // =========================================================================

  Future<bool> _maybeAutoRefreshProgram({
    required TrainingProgram program,
    required HealthProfile profile,
    required DailyPlan plan,
  }) async {
    if (_autoRefreshAttempted) return false;

    if (!plan.shouldRefreshProgram) return false;

    _autoRefreshAttempted = true;

    final refresh = plan.programRefresh!;

    Log.info(
      'HomeViewModel: Auto-refreshing program '
      '(${refresh.reason.name}): ${refresh.message}',
    );

    try {
      await _workoutEngine.regenerateProgram(
        profile: profile,
        previousProgram: program,
        options: const RegenerationOptions(
          type: RegenerationType.fullProgram,
          keepStructure: false,
        ).toMap(),
      );
    } catch (e, s) {
      Log.error(
        'HomeViewModel: Auto-refresh failed',
        error: e,
        stackTrace: s,
      );

      return false;
    }

    await _loadData();
    return true;
  }

  // =========================================================================
  // Coaching
  // =========================================================================

  Future<void> _loadDailyCoaching(String userId, DailyPlan plan) async {
    _isLoadingCoaching = true;
    notifyListeners();

    try {
      _dailyCoaching = await _coachRepository.getOrCreateDailyCoaching(
        userId: userId,
        plan: plan,
        generate: () => _aiCoachEngine.generateDailyCoaching(plan),
      );
    } catch (e, s) {
      Log.error(
        'HomeViewModel: Coaching failed',
        error: e,
        stackTrace: s,
      );

      _dailyCoaching = null;
    } finally {
      _isLoadingCoaching = false;
      notifyListeners();
    }
  }

  Future<void> retryCoaching() async {
    final user = await _userRepository.getCurrentUser();
    final plan = _dailyPlan;

    if (user == null || plan == null) return;

    await _loadDailyCoaching(user.id, plan);
  }

  // =========================================================================
  // Program generation
  // =========================================================================

  Future<void> generateNewProgram() async {
    if (_healthProfile == null || !_healthProfile!.isComplete) {
      _errorMessage = 'Health profile is incomplete.';
      _state = HomeState.error;
      notifyListeners();
      return;
    }

    _isGeneratingProgram = true;
    notifyListeners();

    try {
      await _workoutEngine.generateProgram(
        profile: _healthProfile!,
        previousProgram: _currentProgram,
        options: null,
      );

      await _loadData();
    } catch (e) {
      _errorMessage = 'Failed to generate program: $e';
      _state = HomeState.error;
      notifyListeners();
    } finally {
      _isGeneratingProgram = false;
      notifyListeners();
    }
  }

  Future<void> regenerateProgram(RegenerationOptions options) async {
    if (_healthProfile == null || !_healthProfile!.isComplete) {
      _errorMessage = 'Health profile is incomplete.';
      _state = HomeState.error;
      notifyListeners();
      return;
    }

    _isGeneratingProgram = true;
    notifyListeners();

    try {
      await _workoutEngine.regenerateProgram(
        profile: _healthProfile!,
        previousProgram: _currentProgram!,
        options: options.toMap(),
      );

      await _loadData();

      if (_context != null && _context!.mounted) {
        _showSuccessMessage(_context!, options);
      }
    } catch (e) {
      _errorMessage = 'Failed to regenerate program: $e';
      _state = HomeState.error;
      notifyListeners();

      if (_context != null && _context!.mounted) {
        _showErrorMessage(_context!, e.toString());
      }
    } finally {
      _isGeneratingProgram = false;
      notifyListeners();
    }
  }

  void _showSuccessMessage(BuildContext context, RegenerationOptions options) {
    final message = switch (options.type) {
      RegenerationType.fullProgram =>
        'New training program generated successfully!',
      RegenerationType.specificDay => 'Workout day regenerated successfully!',
      RegenerationType.singleExercise => 'Exercise replaced successfully!',
      RegenerationType.withPreferences => 'Program customized successfully!',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $message'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Failed: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // =========================================================================
  // Program dismissal
  // =========================================================================

  Future<void> dismissExpiredProgram() async {
    await _workoutEngine.clearCurrentProgram();

    _currentProgram = null;
    _dailyPlan = null;

    notifyListeners();
  }

  // =========================================================================
  // Daily Check-in
  // =========================================================================

  Future<void> triggerCheckInIfNeeded(BuildContext context) async {
    final user = await _userRepository.getCurrentUser();

    if (user == null) return;

    if (_healthProfile == null || !_healthProfile!.isComplete) return;

    // ✅ NEW: The morning check-in only makes sense with an active program.
    //
    // _applyCheckIn() requires _currentProgram to compute the DailyPlan,
    // so without one the check-in would be silently discarded and the
    // screen would keep reopening. Guarding here makes the business
    // contract explicit for every caller, not just the HomeTabScreen.
    if (_currentProgram == null) return;

    final today = DateTime.now();

    // The RecoveryRepository is the source of truth.
    //
    // If today's check-in already exists, it has been completed.
    // Therefore we must not show the screen again today.
    final existing = await _recoveryRepository.getDailyCheckIn(
      user.id,
      today,
    );

    if (existing != null) return;

    if (!context.mounted) return;

    final checkIn = await Navigator.of(context).push<DailyCheckIn?>(
      DailyCheckInScreen.route(user.id),
    );

    if (!context.mounted) return;

    if (checkIn != null) {
      // The user completed today's DailyCheckIn.
      //
      // _applyCheckIn() will persist the check-in through
      // DecisionEngine / RecoveryRepository and update the daily plan.
      await _applyCheckIn(checkIn);
    }

    /*
     * checkIn == null means:
     *
     *     User pressed "Plus tard" (Later).
     *
     * IMPORTANT:
     *
     * We deliberately do NOTHING here.
     *
     * "Later" is NOT a business state. It is simply the user closing
     * the form because they are not ready to provide the information
     * yet. Therefore:
     *
     *     - no "skipped" flag
     *     - no database write
     *     - no RecoveryStatus
     *     - today's check-in remains incomplete
     *     - it can be shown again later
     */
  }

  Future<void> _applyCheckIn(DailyCheckIn checkIn) async {
    if (_currentProgram == null || _healthProfile == null) return;

    _state = HomeState.loading;
    notifyListeners();

    try {
      ProgressSnapshot? progressSnapshot;

      try {
        progressSnapshot = await _progressRepository.computeSnapshot(
          checkIn.userId,
        );
      } catch (_) {
        progressSnapshot = null;
      }

      HealthPlatformSnapshot? healthPlatformSnapshot;

      try {
        healthPlatformSnapshot =
            await _healthPlatformRepository.computeSnapshot(
          checkIn.userId,
          weightKg: _healthProfile?.currentWeightKg,
          isTrainingDay: true,
        );
      } catch (_) {
        healthPlatformSnapshot = null;
      }

      // A non-null checkIn is explicitly submitted by the user,
      // so and only so the DecisionEngine may compute RecoveryStatus.
      _dailyPlan = await _decisionEngine.buildDailyPlanAndPersist(
        _currentProgram!,
        _healthProfile!,
        checkIn: checkIn,
        progressSnapshot: progressSnapshot,
        healthPlatformSnapshot: healthPlatformSnapshot,
      );

      _state = HomeState.loaded;
      notifyListeners();

      if (_dailyPlan != null) {
        await _loadDailyCoaching(checkIn.userId, _dailyPlan!);
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = HomeState.error;
      notifyListeners();
    }
  }

  // =========================================================================
  // Manual refresh
  // =========================================================================

  Future<void> refresh() async {
    await _loadData();
  }

  // =========================================================================
  // Context
  // =========================================================================

  void setContext(BuildContext context) {
    _context = context;
  }
}
