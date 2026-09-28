import 'package:gymgenius/domain/entities/training_program.dart';
import 'package:gymgenius/engines/decision_engine/Progression/deload_planner.dart';
import 'package:gymgenius/engines/decision_engine/Progression/mesocycle_planner.dart';
import 'package:gymgenius/engines/decision_engine/Progression/phase_planner.dart';
import 'package:gymgenius/engines/decision_engine/Progression/week_progression_calculator.dart';

import '../models/program_progress.dart';

/// Computes the current progression state of a TrainingProgram.
///
/// This service is the single source of truth for temporal progression.
///
/// Responsibilities:
///
/// • current week
/// • current phase
/// • current mesocycle
/// • current microcycle
/// • weekly progression prescription
/// • deload planning
/// • completion
///
/// It never modifies the TrainingProgram.
///
/// [now] is the reference date used to calculate temporal progression.
/// Supplying it makes the service deterministic and testable.
class ProgramProgressService {
  final PhasePlanner _phasePlanner;
  final MesocyclePlanner _mesocyclePlanner;
  final WeekProgressionCalculator _weekProgressionCalculator;
  final DeloadPlanner _deloadPlanner;

  const ProgramProgressService({
    PhasePlanner phasePlanner = const PhasePlanner(),
    MesocyclePlanner mesocyclePlanner = const MesocyclePlanner(),
    WeekProgressionCalculator weekProgressionCalculator =
        const WeekProgressionCalculator(),
    DeloadPlanner deloadPlanner = const DeloadPlanner(),
  })  : _phasePlanner = phasePlanner,
        _mesocyclePlanner = mesocyclePlanner,
        _weekProgressionCalculator = weekProgressionCalculator,
        _deloadPlanner = deloadPlanner;

  ProgramProgress calculate(
    TrainingProgram program, {
    DateTime? now,
  }) {
    final referenceDate = now ?? DateTime.now();

    final currentWeek = _calculateCurrentWeek(
      program,
      now: referenceDate,
    );

    final phase = _phasePlanner.phaseForWeek(
      currentWeek: currentWeek,
      durationWeeks: program.durationWeeks,
    );

    final mesocycleInfo = _mesocyclePlanner.calculate(
      currentWeek: currentWeek,
    );

    final weekProgression = _weekProgressionCalculator.calculate(
      currentWeek: currentWeek,
      durationWeeks: program.durationWeeks,
      phase: phase,
    );

    final deloadPlan = _deloadPlanner.calculate(
      currentWeek: currentWeek,
      durationWeeks: program.durationWeeks,
      phase: phase,
    );

    return ProgramProgress(
      currentWeek: currentWeek,
      totalWeeks: program.durationWeeks,
      currentPhase: phase,
      mesocycleInfo: mesocycleInfo,
      weekProgression: weekProgression,
      deloadPlan: deloadPlan,
      weeksRemaining: _calculateWeeksRemaining(
        currentWeek: currentWeek,
        durationWeeks: program.durationWeeks,
      ),
      completion: _calculateCompletion(
        currentWeek: currentWeek,
        durationWeeks: program.durationWeeks,
      ),
    );
  }

  // ----------------------------------------------------------
  // Current week
  // ----------------------------------------------------------

  int _calculateCurrentWeek(
    TrainingProgram program, {
    required DateTime now,
  }) {
    final referenceDay = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final programStartDay = DateTime(
      program.createdAt.year,
      program.createdAt.month,
      program.createdAt.day,
    );

    final daysSinceStart = referenceDay.difference(programStartDay).inDays;

    if (daysSinceStart < 0) {
      return 1;
    }

    final week = (daysSinceStart ~/ 7) + 1;

    return week.clamp(
      1,
      program.durationWeeks,
    );
  }

  // ----------------------------------------------------------
  // Weeks remaining
  // ----------------------------------------------------------

  int _calculateWeeksRemaining({
    required int currentWeek,
    required int durationWeeks,
  }) {
    final remaining = durationWeeks - currentWeek;

    return remaining < 0 ? 0 : remaining;
  }

  // ----------------------------------------------------------
  // Completion
  // ----------------------------------------------------------

  double _calculateCompletion({
    required int currentWeek,
    required int durationWeeks,
  }) {
    if (durationWeeks <= 0) {
      return 0;
    }

    final completion = currentWeek / durationWeeks;

    return completion.clamp(0.0, 1.0);
  }
}
