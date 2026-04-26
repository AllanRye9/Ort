import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../widgets/skeleton_loader.dart';

final _leaderboardProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, scope) => ref.read(apiServiceProvider).getLeaderboard(scope: scope),
);

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _scope = 'global';

  @override
  Widget build(BuildContext context) {
    final lb = ref.watch(_leaderboardProvider(_scope));

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'global', label: Text('Global')),
                ButtonSegment(value: 'company', label: Text('Company')),
                ButtonSegment(value: 'organization', label: Text('Org')),
              ],
              selected: {_scope},
              onSelectionChanged: (s) => setState(() => _scope = s.first),
            ),
          ),
          Expanded(
            child: lb.when(
              loading: () => ListView.builder(
                itemCount: 10,
                itemBuilder: (_, __) => const ListTileSkeleton(),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                final entries =
                    (data['entries'] as List).cast<Map<String, dynamic>>();
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final rank = e['rank'] as int? ?? i + 1;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: rank <= 3
                            ? const Color(0xFFFFD700)
                            : Colors.grey[200],
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: rank <= 3 ? Colors.white : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        '${e['first_name']} ${e['last_name']}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('Level ${e['level']}'),
                      trailing: Text(
                        '${e['xp_total']} XP',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
