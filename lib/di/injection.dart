import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:gymgenius/data/repositories/auth_repository_impl.dart';
import 'package:gymgenius/data/repositories/health_repository_impl.dart';
import 'package:gymgenius/data/repositories/nutrition_repository_impl.dart';
import 'package:gymgenius/data/repositories/coach_repository_impl.dart';
import 'package:gymgenius/data/repositories/health_platform_repository_impl.dart';
import 'package:gymgenius/data/repositories/progress_repository_impl.dart';
import 'package:gymgenius/data/repositories/recovery_repository_impl.dart';
import 'package:gymgenius/data/repositories/tracking_repository_impl.dart';
import 'package:gymgenius/data/repositories/user_repository_impl.dart';
import 'package:gymgenius/data/repositories/workout_repository_impl.dart';

import 'package:gymgenius/domain/repositories/auth_repository.dart';
import 'package:gymgenius/domain/repositories/health_repository.dart';
import 'package:gymgenius/domain/repositories/nutrition_repository.dart';
import 'package:gymgenius/domain/repositories/coach_repository.dart';
import 'package:gymgenius/domain/repositories/health_platform_repository.dart';
import 'package:gymgenius/domain/repositories/progress_repository.dart';
import 'package:gymgenius/domain/repositories/recovery_repository.dart';
import 'package:gymgenius/domain/repositories/tracking_repository.dart';
import 'package:gymgenius/domain/repositories/user_repository.dart';
import 'package:gymgenius/domain/repositories/workout_repository.dart';

import 'package:gymgenius/engines/decision_engine/decision_engine.dart';
import 'package:gymgenius/engines/decision_engine/Progression/program_progress_service.dart';
import 'package:gymgenius/engines/decision_engine/rules/deload_rule.dart';
import 'package:gymgenius/engines/decision_engine/rules/equipment_rule.dart';
import 'package:gymgenius/engines/decision_engine/rules/injury_rule.dart';
import 'package:gymgenius/engines/decision_engine/rules/nutrition/nutrition_plan_builder.dart';
import 'package:gymgenius/engines/decision_engine/rules/nutrition/nutrition_rule.dart';
import 'package:gymgenius/engines/decision_engine/rules/health_platform_rule.dart';
import 'package:gymgenius/engines/decision_engine/rules/progress_rule.dart';
import 'package:gymgenius/engines/decision_engine/rules/progression_rule.dart';
import 'package:gymgenius/engines/decision_engine/rules/recovery_rule.dart';
import 'package:gymgenius/engines/decision_engine/rules/safety_rule.dart';
import 'package:gymgenius/engines/health_platform/health_platform_engine.dart';
import 'package:gymgenius/presentation/viewmodels/health_platform_viewmodel.dart';
import 'package:gymgenius/engines/decision_engine/services/conflict_resolver.dart';
import 'package:gymgenius/engines/decision_engine/services/deload_service.dart';
import 'package:gymgenius/engines/decision_engine/services/exercise_substitution_service.dart';
import 'package:gymgenius/engines/decision_engine/services/intensity_adjustment_service.dart';
import 'package:gymgenius/engines/decision_engine/services/recovery_session_service.dart';
import 'package:gymgenius/engines/decision_engine/services/volume_adjustment_service.dart';
import 'package:gymgenius/engines/decision_engine/services/workout_adaptation_service.dart';
import 'package:gymgenius/engines/decision_engine/builders/today_workout_builder.dart';

import 'package:gymgenius/engines/workout_engine/optimizers/local_program_optimizer.dart';
import 'package:gymgenius/engines/workout_engine/optimizers/program_optimizer.dart';
import 'package:gymgenius/engines/workout_engine/providers/exercise_replacement_provider.dart';
import 'package:gymgenius/engines/workout_engine/services/generation_service.dart';
import 'package:gymgenius/engines/workout_engine/workout_engine.dart';
import 'package:gymgenius/engines/nutrition_engine/nutrition_engine.dart';
import 'package:gymgenius/engines/ai_coach/ai_coach_engine.dart';
import 'package:gymgenius/engines/ai_coach/ai_config.dart';
import 'package:gymgenius/engines/ai_coach/providers/gemini_coach_provider.dart';
import 'package:gymgenius/engines/ai_coach/providers/local_coach_provider.dart';
import 'package:gymgenius/engines/progress_engine/progress_engine.dart';
import 'package:gymgenius/engines/recovery_engine/recovery_engine.dart';
import 'package:gymgenius/presentation/viewmodels/coach_viewmodel.dart';

import 'package:gymgenius/core/services/workout_timer_notification_service.dart';
import 'package:gymgenius/data/repositories/workout_session_settings_repository.dart';
import 'package:gymgenius/presentation/blocs/auth/auth_bloc.dart';
import 'package:gymgenius/presentation/blocs/exercise_library/exercise_library_bloc.dart';
import 'package:gymgenius/presentation/blocs/login/login_bloc.dart';
import 'package:gymgenius/presentation/blocs/signup/signup_bloc.dart';

import 'package:gymgenius/presentation/providers/workout_session_manager.dart';
import 'package:gymgenius/presentation/providers/workout_session_settings_controller.dart';

import 'package:gymgenius/presentation/viewmodels/home_viewmodel.dart';
import 'package:gymgenius/presentation/viewmodels/profile_viewmodel.dart';
import 'package:gymgenius/presentation/viewmodels/tracking_viewmodel.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // ============================================================
  // Secure Storage
  // ============================================================
  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  // ============================================================
  // Repositories
  // ============================================================
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(),
  );
  getIt.registerLazySingleton<HealthRepository>(
    () => HealthRepositoryImpl(),
  );
  getIt.registerLazySingleton<WorkoutRepository>(
    () => WorkoutRepositoryImpl(),
  );

  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      userRepository: getIt<UserRepository>(),
      healthRepository: getIt<HealthRepository>(),
      secureStorage: getIt<FlutterSecureStorage>(),
    ),
  );

  getIt.registerLazySingleton<TrackingRepository>(
    () => TrackingRepositoryImpl(
      workoutRepository: getIt<WorkoutRepository>(),
    ),
  );

  getIt.registerLazySingleton<NutritionRepository>(
    () => const NutritionRepositoryImpl(),
  );

  getIt.registerLazySingleton<RecoveryRepository>(
    () => const RecoveryRepositoryImpl(),
  );

  getIt.registerLazySingleton<ProgressEngine>(
    () => const ProgressEngine(),
  );

  getIt.registerLazySingleton<ProgressRepository>(
    () => ProgressRepositoryImpl(
      engine: getIt<ProgressEngine>(),
      recoveryRepository: getIt<RecoveryRepository>(),
      workoutRepository: getIt<WorkoutRepository>(),
      healthRepository: getIt<HealthRepository>(),
    ),
  );

  getIt.registerLazySingleton<CoachRepository>(
    () => const CoachRepositoryImpl(),
  );

  getIt.registerLazySingleton<HealthPlatformEngine>(
    () => const HealthPlatformEngine(),
  );

  getIt.registerLazySingleton<HealthPlatformRepository>(
    () => HealthPlatformRepositoryImpl(
      engine: getIt<HealthPlatformEngine>(),
      recoveryRepository: getIt<RecoveryRepository>(),
    ),
  );

  // ============================================================
  // Workout Engine
  // ============================================================
  getIt.registerFactory<ProgramOptimizer>(() => const LocalProgramOptimizer());
  getIt.registerLazySingleton<ExerciseReplacementProvider>(
    () => const ExerciseReplacementProvider(),
  );

  getIt.registerLazySingleton<GenerationService>(() => GenerationService());
  getIt.registerLazySingleton<WorkoutEngine>(() => WorkoutEngine());

  // ============================================================
  // Nutrition Engine
  // ============================================================
  getIt.registerLazySingleton<NutritionEngine>(
    () => NutritionEngine(
      nutritionRepository: getIt<NutritionRepository>(),
    ),
  );

  // ============================================================
  // Recovery Engine
  // ============================================================
  getIt.registerLazySingleton<RecoveryEngine>(
    () => RecoveryEngine(
      repository: getIt<RecoveryRepository>(),
    ),
  );

  // ============================================================
  // AI Coach
  // ============================================================
  getIt.registerLazySingleton<AICoachEngine>(
    () => AICoachEngine(
      primary: AIConfig.canUseCoachCloud
          ? GeminiCoachProvider()
          : const LocalCoachProvider(),
      local: const LocalCoachProvider(),
    ),
  );

  // ============================================================
  // Decision Engine
  // ============================================================

  // Progression
  getIt.registerLazySingleton<ProgramProgressService>(
    () => const ProgramProgressService(),
  );

  // Builder
  getIt.registerLazySingleton<TodayWorkoutBuilder>(
    () => const TodayWorkoutBuilder(),
  );

  // Adaptation services

  getIt.registerLazySingleton<VolumeAdjustmentService>(
    () => const VolumeAdjustmentService(),
  );

  getIt.registerLazySingleton<IntensityAdjustmentService>(
    () => const IntensityAdjustmentService(),
  );

  getIt.registerLazySingleton<ExerciseSubstitutionService>(
    () => ExerciseSubstitutionService(
      replacementProvider: getIt<ExerciseReplacementProvider>(),
    ),
  );

  getIt.registerLazySingleton<RecoverySessionService>(
    () => const RecoverySessionService(),
  );

  getIt.registerLazySingleton<DeloadService>(
    () => const DeloadService(),
  );

// Workout adaptation

  getIt.registerLazySingleton<WorkoutAdaptationService>(
    () => WorkoutAdaptationService(
      volumeAdjustmentService: getIt(),
      intensityAdjustmentService: getIt(),
      exerciseSubstitutionService: getIt(),
      recoverySessionService: getIt(),
      deloadService: getIt(),
    ),
  );

// ------------------------------------------------------------
// Rules
// ------------------------------------------------------------

  getIt.registerLazySingleton<DeloadRule>(
    () => const DeloadRule(),
  );

  getIt.registerLazySingleton<ProgressionRule>(
    () => const ProgressionRule(),
  );

  getIt.registerLazySingleton<ProgressRule>(
    () => const ProgressRule(),
  );

  getIt.registerLazySingleton<HealthPlatformRule>(
    () => const HealthPlatformRule(),
  );

  getIt.registerLazySingleton<RecoveryRule>(
    () => const RecoveryRule(),
  );

  getIt.registerLazySingleton<NutritionPlanBuilder>(
    () => NutritionPlanBuilder(
      nutritionEngine: getIt<NutritionEngine>(),
    ),
  );

  getIt.registerLazySingleton<NutritionRule>(
    () => NutritionRule(
      planBuilder: getIt<NutritionPlanBuilder>(),
    ),
  );

  getIt.registerLazySingleton<SafetyRule>(
    () => const SafetyRule(),
  );

  getIt.registerLazySingleton<EquipmentRule>(
    () => const EquipmentRule(),
  );

  getIt.registerLazySingleton<InjuryRule>(
    () => const InjuryRule(),
  );

// ------------------------------------------------------------
// Conflict Resolver
// ------------------------------------------------------------

  getIt.registerLazySingleton<ConflictResolver>(
    () => const ConflictResolver(),
  );

// ------------------------------------------------------------
// Decision Engine
// ------------------------------------------------------------

  getIt.registerLazySingleton<DecisionEngine>(
    () => DecisionEngine(
      programProgressService: getIt(),
      todayWorkoutBuilder: getIt(),
      workoutAdaptationService: getIt(),
      conflictResolver: getIt(),
      nutritionRule: getIt<NutritionRule>(),
      recoveryEngine: getIt<RecoveryEngine>(),
      rules: [
        getIt<InjuryRule>(),
        getIt<SafetyRule>(),
        getIt<RecoveryRule>(),
        getIt<DeloadRule>(),
        getIt<ProgressionRule>(),
        getIt<EquipmentRule>(),
        getIt<ProgressRule>(),
        getIt<HealthPlatformRule>(),
        getIt<NutritionRule>(),
      ],
    ),
  );

  // ============================================================
  // Workout session services
  // ============================================================
  getIt.registerLazySingleton<WorkoutTimerNotificationService>(
    () => WorkoutTimerNotificationService(),
  );
  getIt.registerLazySingleton<WorkoutSessionSettingsRepository>(
    () => WorkoutSessionSettingsRepository(),
  );
  getIt.registerLazySingleton<WorkoutSessionManager>(
    () => WorkoutSessionManager(
      notificationService: getIt<WorkoutTimerNotificationService>(),
    ),
  );
  getIt.registerLazySingleton<WorkoutSessionSettingsController>(
    () => WorkoutSessionSettingsController(
      repository: getIt<WorkoutSessionSettingsRepository>(),
      sessionManager: getIt<WorkoutSessionManager>(),
    ),
  );

  // ============================================================
  // Providers (ChangeNotifier)
  // ============================================================
  // ============================================================
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(
      authRepository: getIt<AuthRepository>(),
      healthRepository: getIt<HealthRepository>(),
    ),
  );

  getIt.registerFactory<LoginBloc>(
    () => LoginBloc(
      authRepository: getIt<AuthRepository>(),
    ),
  );

  getIt.registerFactory<SignUpBloc>(
    () => SignUpBloc(
      authRepository: getIt<AuthRepository>(),
    ),
  );

  getIt.registerFactory(() => ExerciseLibraryBloc());

  // ============================================================
  // ViewModels
  // ============================================================
  getIt.registerFactory<HomeViewModel>(
    () => HomeViewModel(
      workoutEngine: getIt<WorkoutEngine>(),
      userRepository: getIt<UserRepository>(),
      healthRepository: getIt<HealthRepository>(),
      decisionEngine: getIt<DecisionEngine>(),
      recoveryRepository: getIt<RecoveryRepository>(),
      progressRepository: getIt<ProgressRepository>(),
      aiCoachEngine: getIt<AICoachEngine>(),
      coachRepository: getIt<CoachRepository>(),
      healthPlatformRepository: getIt<HealthPlatformRepository>(),
    ),
  );

  getIt.registerFactory<CoachViewModel>(
    () => CoachViewModel(
      engine: getIt<AICoachEngine>(),
      coachRepository: getIt<CoachRepository>(),
      progressRepository: getIt<ProgressRepository>(),
      userRepository: getIt<UserRepository>(),
    ),
  );

  getIt.registerFactory<HealthPlatformViewModel>(
    () => HealthPlatformViewModel(
      repository: getIt<HealthPlatformRepository>(),
      userRepository: getIt<UserRepository>(),
      healthRepository: getIt<HealthRepository>(),
    ),
  );

  getIt.registerFactory<TrackingViewModel>(
    () => TrackingViewModel(
      workoutRepository: getIt<WorkoutRepository>(),
      trackingRepository: getIt<TrackingRepository>(),
      userRepository: getIt<UserRepository>(),
      progressRepository: getIt<ProgressRepository>(),
    ),
  );

  getIt.registerFactory<ProfileViewModel>(
    () => ProfileViewModel(
      healthRepository: getIt<HealthRepository>(),
      userRepository: getIt<UserRepository>(),
    ),
  );

  // ============================================================
  // Note: ExerciseLoggingViewModel and ActiveWorkoutViewModel
  // are not registered here because they depend on dynamic
  // parameters (Exercise, BuildContext). They should be
  // instantiated directly in the UI where the context and
  // exercise are available.
  // ============================================================
}
