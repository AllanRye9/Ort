import 'package:flutter/material.dart';

/// Displays a daily challenge with animated progress indicator.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.description,
    required this.goalType,
    required this.goalValue,
    required this.xpReward,
    required this.progress,
    required this.completed,
  });

  final String description;
  final String goalType;
  final int goalValue;
  final int xpReward;
  final int progress;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final pct = goalValue > 0 ? (progress / goalValue).clamp(0.0, 1.0) : 0.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed ? Icons.check_circle : Icons.emoji_events_outlined,
                  color: completed ? Colors.green : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    description,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+$xpReward XP',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: pct),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completed ? Colors.green : colorScheme.primary,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$progress / $goalValue',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
