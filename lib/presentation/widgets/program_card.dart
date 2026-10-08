// lib/presentation/widgets/program_card.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/domain/entities/exercise.dart';
import 'package:gymgenius/domain/entities/health_profile.dart';
import 'package:gymgenius/domain/entities/training_program.dart';
import 'package:gymgenius/presentation/screens/daily_workout_detail_screen.dart';
import 'package:gymgenius/presentation/widgets/exercise/exercise_media.dart';

class ProgramCard extends StatelessWidget {
  final String dayKey;
  final List<Exercise> exercises;
  final bool isToday;
  final TrainingProgram program;
  final HealthProfile healthProfile;

  const ProgramCard({
    super.key,
    required this.dayKey,
    required this.exercises,
    required this.program,
    required this.healthProfile,
    this.isToday = false,
  });

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _navigateToDetail(BuildContext context) {
    if (exercises.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DailyWorkoutDetailScreen(
            dayTitle: "${_capitalize(dayKey)} Workout Details",
            initialExercises: exercises,
            programIdForLog: program.id,
            dayKeyForLog: dayKey.toLowerCase(),
            healthProfile: healthProfile,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final bool isRestDay = exercises.isEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: isRestDay ? 0.5 : (isToday ? 4.0 : 1.5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: isToday && !isRestDay
            ? BorderSide(color: colorScheme.primary, width: 1.5)
            : (isRestDay
                ? BorderSide(
                    color: colorScheme.outline.withAlpha(77), width: 0.8)
                : BorderSide.none),
      ),
      color: isRestDay ? colorScheme.surfaceContainerLowest : null,
      child: InkWell(
        onTap: isRestDay ? null : () => _navigateToDetail(context),
        splashColor: isRestDay ? Colors.transparent : null,
        highlightColor: isRestDay ? Colors.transparent : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _capitalize(dayKey),
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isToday && !isRestDay
                            ? colorScheme.primary
                            : (isRestDay
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isRestDay)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: isToday
                          ? colorScheme.primary
                          : colorScheme.onSurface.withAlpha(178),
                    )
                  else
                    Chip(
                      label: Text(
                        "REST",
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      backgroundColor:
                          colorScheme.secondaryContainer.withAlpha(178),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isRestDay) ...[
                ...exercises.take(3).map((ex) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Thumbnail (image + optional GIF badge)
                          ExerciseMediaThumbnail(
                            exerciseId: ex.id,
                            size: 40,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "${ex.name} (${ex.sets}x${ex.reps})",
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    )),
                if (exercises.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 50),
                    child: Text(
                      "...and ${exercises.length - 3} more.",
                      style: textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant.withAlpha(150),
                      ),
                    ),
                  ),
              ] else
                Text(
                  "Take this day to recover and recharge!",
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
