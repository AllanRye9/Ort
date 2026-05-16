import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';

final _myReviewsProvider = FutureProvider.autoDispose<List<ReviewModel>>((ref) async {
  final auth = ref.read(authProvider);
  final userId = auth.userId;
  if (userId == null) return const <ReviewModel>[];

  final role = auth.role ?? 'user';
  final api = ref.read(apiServiceProvider);
  List<dynamic> data;

  if (role == 'user') {
    data = await api.getReviews(reviewerId: userId);
  } else if (role == 'agent') {
    data = await api.getReviews(agentId: userId);
  } else if (role == 'company' || role == 'organization') {
    final tenant = await api.getTenantByOwner(userId);
    final tenantId = tenant?['id'] as int?;
    if (tenantId == null) return const <ReviewModel>[];
    data = await api.getReviews(tenantId: tenantId);
  } else {
    return const <ReviewModel>[];
  }

  return data
      .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myReviewsProvider);
    final role = ref.watch(authProvider).role ?? 'user';
    final title = role == 'user' ? 'My Reviews' : 'Business Reviews';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (reviews) {
          if (reviews.isEmpty) {
            return const Center(child: Text('No reviews found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
              final review = reviews[i];
              return Card(
                child: ListTile(
                  title: Text(review.title ?? 'Review #${review.id}'),
                  subtitle: Text(
                    review.body?.trim().isNotEmpty == true
                        ? review.body!
                        : 'No comment provided.',
                  ),
                  trailing: _RatingChip(rating: review.rating),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: reviews.length,
          );
        },
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            '$rating',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
