import 'package:flutter/material.dart';
import 'package:gymgenius/domain/entities/progress_snapshot.dart';
import 'package:gymgenius/domain/enums/trend_direction.dart';

class ConsistencyProgressScreen extends StatelessWidget {
  final ProgressSnapshot snapshot;

  const ConsistencyProgressScreen({super.key, required this.snapshot});

  static Route<void> route(ProgressSnapshot snapshot) {
    return MaterialPageRoute(
      builder: (_) => ConsistencyProgressScreen(snapshot: snapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consistency = snapshot.consistency;
    final hasData = consistency?.hasSufficientData ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Consistency')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasData)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No planned workouts found in the lookback period.',
                ),
              ),
            )
          else ...[
            _StatCard(
              label: 'Consistency score',
              value: '${consistency!.consistencyScore}%',
            ),
            _StatCard(
              label: 'Completed / planned',
              value:
                  '${consistency.completedWorkouts} / ${consistency.plannedWorkouts}',
            ),
            _StatCard(
              label: 'Weekly frequency',
              value: consistency.weeklyFrequency.toStringAsFixed(1),
            ),
            // "Consecutive training days" removed — it reset to 0 on
            // every rest day, even rest days the user's own program
            // schedules on purpose (e.g. 5-day program, weekends off).
            // It punished exactly the adherence it was meant to
            // reward, and added nothing beyond consistencyScore /
            // weeklyFrequency above. The underlying
            // WorkoutConsistency.consecutiveTrainingDays field is
            // still computed but no longer shown.
            _StatCard(
              label: 'Trend',
              value: consistency.trend.displayName,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
