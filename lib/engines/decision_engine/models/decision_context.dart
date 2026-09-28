import 'package:gymgenius/domain/entities/health_platform_snapshot.dart';
import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/entities/nutrition_adherence_snapshot.dart';
import 'package:gymgenius/domain/entities/progress_snapshot.dart';
import 'package:gymgenius/domain/entities/recovery_status.dart';
import 'package:gymgenius/domain/entities/today_workout.dart';
import 'package:gymgenius/domain/entities/training_program.dart';
import 'package:gymgenius/engines/decision_engine/models/program_progress.dart';

/// Complete snapshot of everything the Decision Engine knows
/// about the user at the moment a decision is made.
///
/// This is intentionally the single input of every decision rule.
/// Raw nutrition logs never enter the Decision Engine directly; the
/// synthesized [NutritionAdherenceSnapshot] is the nutrition boundary.
class DecisionContext {
  final DateTime now;
  final HealthProfile healthProfile;
  final TrainingProgram trainingProgram;
  final ProgramProgress programProgress;
  final TodayWorkout todayWorkout;
  final RecoveryStatus? recoveryStatus;
  final ProgressSnapshot? progressSnapshot;
  final HealthPlatformSnapshot? healthPlatformSnapshot;
  final NutritionAdherenceSnapshot? nutritionAdherenceSnapshot;

  const DecisionContext({
    required this.now,
    required this.healthProfile,
    required this.trainingProgram,
    required this.programProgress,
    required this.todayWorkout,
    this.recoveryStatus,
    this.progressSnapshot,
    this.healthPlatformSnapshot,
    this.nutritionAdherenceSnapshot,
  });

  DecisionContext copyWith({
    DateTime? now,
    HealthProfile? healthProfile,
    TrainingProgram? trainingProgram,
    ProgramProgress? programProgress,
    TodayWorkout? todayWorkout,
    RecoveryStatus? recoveryStatus,
    ProgressSnapshot? progressSnapshot,
    HealthPlatformSnapshot? healthPlatformSnapshot,
    NutritionAdherenceSnapshot? nutritionAdherenceSnapshot,
  }) {
    return DecisionContext(
      now: now ?? this.now,
      healthProfile: healthProfile ?? this.healthProfile,
      trainingProgram: trainingProgram ?? this.trainingProgram,
      programProgress: programProgress ?? this.programProgress,
      todayWorkout: todayWorkout ?? this.todayWorkout,
      recoveryStatus: recoveryStatus ?? this.recoveryStatus,
      progressSnapshot: progressSnapshot ?? this.progressSnapshot,
      healthPlatformSnapshot:
          healthPlatformSnapshot ?? this.healthPlatformSnapshot,
      nutritionAdherenceSnapshot:
          nutritionAdherenceSnapshot ?? this.nutritionAdherenceSnapshot,
    );
  }

  @override
  String toString() {
    return '''
DecisionContext(
  now: $now,
  currentWeek: ${programProgress.currentWeek},
  phase: ${programProgress.currentPhase},
  completion: ${(programProgress.completion * 100).toStringAsFixed(1)}%,
  plannedExercises: ${todayWorkout.plannedExerciseCount},
  finalExercises: ${todayWorkout.finalExerciseCount},
  adapted: ${todayWorkout.isAdapted},
  nutritionSnapshot: ${nutritionAdherenceSnapshot != null},
  nutritionCoverage: ${nutritionAdherenceSnapshot?.mealSlotCoverage},
  nutritionAdherence: ${nutritionAdherenceSnapshot?.adherenceScore},
)
''';
  }
}
