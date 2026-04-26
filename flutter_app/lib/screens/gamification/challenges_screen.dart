import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../widgets/challenge_card.dart';
import '../../widgets/skeleton_loader.dart';

final _challengesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.read(apiServiceProvider).getTodayChallenges();
});

final _xpProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(apiServiceProvider).getMyXP();
});

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(_challengesProvider);
    final xpAsync = ref.watch(_xpProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Challenges')),
      body: Column(
        children: [
          xpAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: ListTileSkeleton(),
            ),
            error: (e, _) => const SizedBox.shrink(),
            data: (xp) => _XPCard(xp: xp),
          ),
          Expanded(
            child: challengesAsync.when(
              loading: () => ListView.builder(
                itemCount: 3,
                itemBuilder: (_, __) => const ListTileSkeleton(),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (challenges) => challenges.isEmpty
                  ? const Center(child: Text('No challenges today. Check back tomorrow!'))
                  : ListView.builder(
                      itemCount: challenges.length,
                      itemBuilder: (ctx, i) {
                        final ch = challenges[i] as Map<String, dynamic>;
                        return ChallengeCard(
                          description: ch['description'] as String? ?? '',
                          goalType: ch['goal_type'] as String? ?? '',
                          goalValue: ch['goal_value'] as int? ?? 1,
                          xpReward: ch['xp_reward'] as int? ?? 10,
                          progress: ch['progress'] as int? ?? 0,
                          completed: ch['completed'] as bool? ?? false,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _XPCard extends StatelessWidget {
  const _XPCard({required this.xp});

  final Map<String, dynamic> xp;

  @override
  Widget build(BuildContext context) {
    final level = xp['level'] as int? ?? 1;
    final total = xp['xp_total'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              'L$level',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Progress',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '$total XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.emoji_events, color: Colors.amber, size: 36),
        ],
      ),
    );
  }
}
