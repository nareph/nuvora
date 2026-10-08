// lib/presentation/screens/exercise_library/exercise_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';
import 'package:gymgenius/presentation/widgets/exercise/exercise_description.dart';

import '../../../domain/enums/exports.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final ExercisePoolEntry exercise;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
  });

  static Route<void> route(ExercisePoolEntry exercise) {
    return MaterialPageRoute(
      builder: (_) => ExerciseDetailScreen(exercise: exercise),
      settings: RouteSettings(name: '/exercise_detail/${exercise.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showExerciseInfo(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ NEW: media block (GIF + attribution) at the top.
            _ExerciseMedia(exercise: exercise),
            const SizedBox(height: 16),

            // Header with muscle groups
            _buildHeader(context),
            const SizedBox(height: 24),

            // Description
            ExerciseDescription(description: exercise.description),
            const SizedBox(height: 24),

            // Details
            _buildDetails(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.name,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...exercise.targetMuscles.map((muscle) => Chip(
                  label: Text(muscle.displayName),
                  backgroundColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                  avatar: const Icon(Icons.fitness_center, size: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                )),
            Chip(
              label: Text(exercise.equipmentType.displayName),
              backgroundColor: colorScheme.secondaryContainer,
              labelStyle: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
              avatar: const Icon(Icons.build, size: 16),
            ),
            Chip(
              label: Text(exercise.category.displayName),
              backgroundColor: colorScheme.tertiaryContainer,
              labelStyle: TextStyle(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w500,
              ),
              avatar: const Icon(Icons.category, size: 16),
            ),
            Chip(
              label: Text(exercise.difficulty.displayName),
              backgroundColor: _getDifficultyColor(context),
              labelStyle: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              avatar: _getDifficultyIcon(),
            ),
            if (exercise.usesWeight)
              Chip(
                label: Text(exercise.weightSuggestion ?? 'Weighted'),
                backgroundColor: colorScheme.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                avatar: const Icon(Icons.fitness_center, size: 16),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercise Details',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(context, 'Category', exercise.category.displayName),
            _buildDetailRow(
                context, 'Difficulty', exercise.difficulty.displayName),
            _buildDetailRow(
                context, 'Equipment', exercise.equipmentType.displayName),
            _buildDetailRow(context, 'Movement Pattern',
                exercise.movementPattern.displayName),
            _buildDetailRow(
                context, 'Mechanics', exercise.mechanics.displayName),
            _buildDetailRow(
                context, 'Force Type', exercise.forceType.displayName),
            _buildDetailRow(
                context, 'Laterality', exercise.laterality.displayName),
            _buildDetailRow(
                context, 'Plane of Motion', exercise.planeOfMotion.displayName),
            if (exercise.weightSuggestion != null)
              _buildDetailRow(
                  context, 'Weight Suggestion', exercise.weightSuggestion!),
            if (exercise.usesWeight)
              _buildDetailRow(context, 'Uses Weight', 'Yes'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (exercise.difficulty) {
      case ExerciseDifficulty.beginner:
        return colorScheme.primaryContainer;
      case ExerciseDifficulty.intermediate:
        return colorScheme.secondaryContainer;
      case ExerciseDifficulty.advanced:
        return colorScheme.errorContainer;
    }
  }

  Widget _getDifficultyIcon() {
    switch (exercise.difficulty) {
      case ExerciseDifficulty.beginner:
        return const Icon(Icons.eco, size: 16);
      case ExerciseDifficulty.intermediate:
        return const Icon(Icons.trending_up, size: 16);
      case ExerciseDifficulty.advanced:
        return const Icon(Icons.auto_awesome, size: 16);
    }
  }

  void _showExerciseInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exercise Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${exercise.id}'),
            const SizedBox(height: 8),
            Text('Category: ${exercise.category.displayName}'),
            const SizedBox(height: 8),
            Text('Difficulty: ${exercise.difficulty.displayName}'),
            if (exercise.mediaAttribution != null) ...[
              const SizedBox(height: 16),
              Text(
                'Media: ${exercise.mediaAttribution}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Media block — shows the GIF with a graceful placeholder + attribution
// ============================================================================

class _ExerciseMedia extends StatelessWidget {
  final ExercisePoolEntry exercise;

  const _ExerciseMedia({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasGif = exercise.gifUrl != null && exercise.gifUrl!.isNotEmpty;

    if (!hasGif) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Card wrapper with rounded corners + shadow.
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 320),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            exercise.gifUrl!,
            fit: BoxFit.contain,
            // Decode at a reasonable size — GIFs are 180×180 but the
            // device pixel ratio might call for ~2x on hi-DPI screens.
            cacheWidth: 360,
            cacheHeight: 360,
            // Keep the last frame visible while the next loop starts.
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: colorScheme.onSurface.withAlpha(102),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preview unavailable',
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Attribution (required by the dataset licence).
        if (exercise.mediaAttribution != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              exercise.mediaAttribution!,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withAlpha(102),
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
