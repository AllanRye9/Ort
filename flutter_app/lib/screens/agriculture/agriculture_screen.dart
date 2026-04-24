import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';
import '../../widgets/listing_card.dart';

final _agricultureListProvider =
    FutureProvider.autoDispose<List<AgricultureListingModel>>((ref) async {
  final data =
      await ref.read(apiServiceProvider).getAgricultureListings(limit: 50);
  return data
      .map((e) =>
          AgricultureListingModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class AgricultureScreen extends ConsumerWidget {
  const AgricultureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_agricultureListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Agriculture Listings')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Listing'),
        onPressed: () {},
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No agriculture listings yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_agricultureListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final a = items[i];
                return ListingCard(
                  icon: Icons.grass,
                  iconColor: Colors.green,
                  title: a.title,
                  subtitle: a.location ?? a.commodityType ?? '',
                  tag: a.category ?? 'Agriculture',
                  status: a.status,
                  price:
                      '\$${a.pricePerUnit.toStringAsFixed(2)}/${a.unit ?? 'unit'}',
                  extras: [
                    if (a.qualityGrade != null) a.qualityGrade!,
                    if (a.moq != null) 'MOQ: ${a.moq}',
                    if (a.isPerishable) '⚠ Perishable',
                  ],
                  onTap: () => ctx.go('/agriculture/${a.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
