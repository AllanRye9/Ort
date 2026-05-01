import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';

final _analyticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final agentId = ref.watch(authProvider).userId;
  if (agentId == null) return {};
  return ref.read(apiServiceProvider).getAgentStats(agentId);
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_analyticsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_analyticsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Failed to load analytics', style: TextStyle(color: cs.error)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(_analyticsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (stats) => _AnalyticsBody(stats: stats),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final totalProperties = stats['total_properties'] as int? ?? 0;
    final totalBids = stats['total_bids'] as int? ?? 0;
    final totalSaves = stats['total_saves'] as int? ?? 0;
    final totalMessages = stats['total_messages'] as int? ?? 0;
    final totalReviews = stats['total_reviews'] as int? ?? 0;
    final avgRating = (stats['avg_rating'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Performance',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Overview of your listings and client engagement',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Rating highlight
          if (totalReviews > 0) ...[
            _RatingCard(avgRating: avgRating, totalReviews: totalReviews),
            const SizedBox(height: 16),
          ],

          // Stats grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                icon: Icons.apartment_rounded,
                label: 'Listings',
                value: totalProperties.toString(),
                color: const Color(0xFF1B5E20),
              ),
              _StatCard(
                icon: Icons.gavel_outlined,
                label: 'Bids Received',
                value: totalBids.toString(),
                color: const Color(0xFF1565C0),
              ),
              _StatCard(
                icon: Icons.bookmark_outlined,
                label: 'Saves / Favourites',
                value: totalSaves.toString(),
                color: const Color(0xFFE65100),
              ),
              _StatCard(
                icon: Icons.chat_bubble_outline,
                label: 'Messages',
                value: totalMessages.toString(),
                color: const Color(0xFF6A1B9A),
              ),
              _StatCard(
                icon: Icons.star_rounded,
                label: 'Reviews',
                value: totalReviews.toString(),
                color: const Color(0xFFF57F17),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          Text(
            'Tips to grow your reach',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._tips(totalProperties, totalReviews, totalBids).map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tip,
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _tips(int listings, int reviews, int bids) {
    final tips = <String>[];
    if (listings == 0) {
      tips.add('Add your first listing to start attracting clients.');
    }
    if (reviews == 0) {
      tips.add('Ask satisfied clients to leave a review on your listings.');
    }
    if (bids == 0 && listings > 0) {
      tips.add(
          'Complete your listing descriptions and add photos to attract bids.');
    }
    if (tips.isEmpty) {
      tips.add('Great work! Keep updating your listings to stay visible.');
      tips.add('Respond to messages quickly to improve client trust.');
    }
    return tips;
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.avgRating, required this.totalReviews});
  final double avgRating;
  final int totalReviews;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.15),
            Colors.amber.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: Colors.amber[700], size: 48),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface),
              ),
              Text(
                '$totalReviews review${totalReviews != 1 ? 's' : ''}',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: List.generate(5, (i) {
              final full = i < avgRating.floor();
              final half = !full && i < avgRating;
              return Icon(
                full
                    ? Icons.star_rounded
                    : (half ? Icons.star_half_rounded : Icons.star_outline_rounded),
                color: Colors.amber[700],
                size: 18,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
