import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../widgets/skeleton_loader.dart';

final _dashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final role = ref.read(authProvider).role ?? 'user';
  return ref.read(apiServiceProvider).getDashboard(role: role);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dashboardProvider);
    final role = ref.read(authProvider).role ?? 'user';

    return Scaffold(
      appBar: AppBar(title: Text('${role[0].toUpperCase()}${role.substring(1)} Dashboard')),
      body: async.when(
        loading: () => ListView.builder(
          itemCount: 4,
          itemBuilder: (_, __) => const ListTileSkeleton(),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => _DashboardContent(data: data),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final activity =
        (data['recent_activity'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final xpTotal = data['xp_total'] as int? ?? 0;
    final level = data['level'] as int? ?? 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _XPSummaryCard(xpTotal: xpTotal, level: level),
        const SizedBox(height: 16),
        if (stats.isNotEmpty) ...[
          Text('Overview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: stats.entries
                .map((e) => _StatCard(label: e.key, value: e.value))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (activity.isNotEmpty) ...[
          Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _ActivityChart(activity: activity),
          const SizedBox(height: 16),
          ...activity.map(
            (a) => ListTile(
              leading: Icon(_activityIcon(a['type'] as String? ?? '')),
              title: Text('${a['type']?.toString().toUpperCase() ?? ''} #${a['id']}'),
              subtitle: Text(a['status']?.toString() ?? ''),
              trailing: a['created_at'] != null
                  ? Text(
                      _formatDate(a['created_at'] as String),
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'property':
        return Icons.apartment_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _XPSummaryCard extends StatelessWidget {
  const _XPSummaryCard({required this.xpTotal, required this.level});

  final int xpTotal;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level $level',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              Text('$xpTotal XP total',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            Text(
              label.replaceAll('_', ' '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.activity});

  final List<Map<String, dynamic>> activity;

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) return const SizedBox.shrink();

    final Map<String, int> counts = {};
    for (final a in activity) {
      final type = a['type'] as String? ?? 'other';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final entries = counts.entries.toList();

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: entries.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value.toDouble(),
                  color: Theme.of(context).colorScheme.primary,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < entries.length) {
                    return Text(entries[idx].key, style: const TextStyle(fontSize: 10));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }
}
