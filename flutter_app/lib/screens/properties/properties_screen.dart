import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';
import '../../widgets/listing_card.dart';

final _propertiesListProvider =
    FutureProvider.autoDispose<List<PropertyModel>>((ref) async {
  final data = await ref.read(apiServiceProvider).getProperties(limit: 50);
  return data
      .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class PropertiesScreen extends ConsumerWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_propertiesListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Properties')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('List Property'),
        onPressed: () => context.go('/properties/create'),
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
                  Icon(Icons.apartment_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No properties listed yet.',
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Listing'),
                    onPressed: () => context.go('/properties/create'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_propertiesListProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final p = items[i];
                return ListingCard(
                  icon: Icons.apartment_rounded,
                  iconColor: Theme.of(ctx).colorScheme.primary,
                  title: p.title,
                  subtitle: p.city ?? p.address,
                  tag: p.propertyType,
                  status: p.status,
                  price: '\$${p.price.toStringAsFixed(0)}',
                  extras: [
                    if (p.bedrooms != null) '${p.bedrooms} bd',
                    if (p.bathrooms != null) '${p.bathrooms} ba',
                    if (p.areaSqft != null) '${p.areaSqft} sqft',
                  ],
                  onTap: () => ctx.go('/properties/${p.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
