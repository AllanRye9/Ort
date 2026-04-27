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
        onPressed: () => context.go('/agriculture/create'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grass_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No agriculture listings yet.',
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Listing'),
                    onPressed: () => context.go('/agriculture/create'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_agricultureListProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final a = items[i];
                final imgUrl =
                    (a.images != null && a.images!.isNotEmpty)
                        ? a.images!.first
                        : null;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + i * 60),
                  curve: Curves.easeOut,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: ListingCard(
                    icon: Icons.grass_rounded,
                    iconColor: const Color(0xFF388E3C),
                    imageUrl: imgUrl,
                    title: a.title,
                    subtitle: a.location ?? a.commodityType ?? '',
                    tag: a.category ?? 'Agriculture',
                    status: a.status,
                    price: '\$${a.pricePerUnit.toStringAsFixed(2)}/${a.unit ?? 'unit'}',
                    extras: [
                      if (a.qualityGrade != null) a.qualityGrade!,
                      if (a.moq != null) 'MOQ: ${a.moq}',
                      if (a.isPerishable) '⚠ Perishable',
                    ],
                    onTap: () => ctx.go('/agriculture/${a.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
