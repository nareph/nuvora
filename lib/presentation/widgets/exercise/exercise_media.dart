// lib/presentation/widgets/exercise/exercise_media.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercises/catalog/exercise_catalog.dart';

/// Small thumbnail (static image + optional GIF badge) for one exercise.
///
/// Looks up the media from the canonical [ExerciseCatalog] using the
/// exercise's ID. Falls back to a category icon if no media is available.
///
/// Use this in lists, cards, and any compact UI. For the full-screen
/// animated GIF, use [ExerciseMediaGif] instead.
class ExerciseMediaThumbnail extends StatelessWidget {
  final String exerciseId;
  final double size;
  final IconData fallbackIcon;

  const ExerciseMediaThumbnail({
    super.key,
    required this.exerciseId,
    this.size = 48,
    this.fallbackIcon = Icons.fitness_center,
  });

  @override
  Widget build(BuildContext context) {
    final entry = ExerciseCatalog.findById(exerciseId);
    final colorScheme = Theme.of(context).colorScheme;

    final hasImage = entry?.imageUrl != null && entry!.imageUrl!.isNotEmpty;
    final hasGif = entry?.gifUrl != null && entry!.gifUrl!.isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.15),
            child: Container(
              width: size,
              height: size,
              color: colorScheme.surfaceContainerHighest,
              child: hasImage
                  ? Image.asset(
                      entry.imageUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      cacheWidth: (size * 2).toInt(),
                      cacheHeight: (size * 2).toInt(),
                      errorBuilder: (_, __, ___) => _fallback(colorScheme),
                    )
                  : _fallback(colorScheme),
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
                    fontSize: size * 0.14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        fallbackIcon,
        size: size * 0.5,
        color: colorScheme.onSurface.withAlpha(102),
      ),
    );
  }
}

/// Full-size animated GIF for the given exercise.
///
/// Renders an empty SizedBox if no GIF is available. Includes the
/// mandatory media attribution below the GIF.
class ExerciseMediaGif extends StatelessWidget {
  final String exerciseId;
  final double? maxHeight;

  const ExerciseMediaGif({
    super.key,
    required this.exerciseId,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final entry = ExerciseCatalog.findById(exerciseId);
    final colorScheme = Theme.of(context).colorScheme;

    final hasGif = entry?.gifUrl != null && entry!.gifUrl!.isNotEmpty;
    if (!hasGif) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: maxHeight ?? 280),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            entry.gifUrl!,
            fit: BoxFit.contain,
            cacheWidth: 360,
            cacheHeight: 360,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _gifFallback(colorScheme),
          ),
        ),
        if (entry.mediaAttribution != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              entry.mediaAttribution!,
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

  Widget _gifFallback(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 40,
            color: colorScheme.onSurface.withAlpha(102),
          ),
          const SizedBox(height: 8),
          Text(
            'Preview unavailable',
            style: TextStyle(color: colorScheme.onSurface.withAlpha(153)),
          ),
        ],
      ),
    );
  }
}
