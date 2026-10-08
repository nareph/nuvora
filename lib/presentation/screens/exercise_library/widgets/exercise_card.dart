// lib/presentation/screens/exercise_library/widgets/exercise_card.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';

import '../../../../domain/enums/exports.dart';

class ExerciseCard extends StatelessWidget {
  final ExercisePoolEntry exercise;
  final VoidCallback onTap;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail (image + optional GIF badge)
              _ExerciseThumbnail(exercise: exercise),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        ...exercise.targetMuscles.take(3).map(
                            (muscle) => _buildTag(context, muscle.displayName)),
                        if (exercise.targetMuscles.length > 3)
                          _buildTag(context,
                              '+${exercise.targetMuscles.length - 3} more'),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withAlpha(102),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(178),
            ),
      ),
    );
  }
}

// ============================================================================
// Thumbnail — image (or icon fallback) + optional "GIF" badge
// ============================================================================

class _ExerciseThumbnail extends StatelessWidget {
  final ExercisePoolEntry exercise;

  const _ExerciseThumbnail({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty;
    final hasGif = exercise.gifUrl != null && exercise.gifUrl!.isNotEmpty;

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 56,
              height: 56,
              color: colorScheme.primaryContainer,
              child: hasImage
                  ? Image.asset(
                      exercise.imageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      // Decode at display size (x2 for hi-DPI).
                      cacheWidth: 112,
                      cacheHeight: 112,
                      errorBuilder: (_, __, ___) => _iconFallback(context),
                    )
                  : _iconFallback(context),
            ),
          ),
          if (hasGif)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'GIF',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconFallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(
        _getExerciseIcon(),
        color: colorScheme.primary,
      ),
    );
  }

  IconData _getExerciseIcon() {
    switch (exercise.category) {
      case ExerciseCategory.compound:
        return Icons.fitness_center;
      case ExerciseCategory.isolation:
        return Icons.track_changes;
      default:
        return Icons.sports_gymnastics;
    }
  }
}
