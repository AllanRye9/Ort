import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';
import '../../widgets/listing_card.dart';

final _mfgListProvider =
    FutureProvider.autoDispose<List<ManufacturingProductModel>>((ref) async {
  final data =
      await ref.read(apiServiceProvider).getManufacturingProducts(limit: 50);
  return data
      .map((e) =>
          ManufacturingProductModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class ManufacturingScreen extends ConsumerWidget {
  const ManufacturingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_mfgListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wholesale Manufacturing')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        onPressed: () {},
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No products listed yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_mfgListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final m = items[i];
                return ListingCard(
                  icon: Icons.factory,
                  iconColor: Colors.orange,
                  title: m.title,
                  subtitle:
                      m.category ?? (m.isLocallyMade ? 'Locally Made' : ''),
                  tag: m.category ?? 'Manufacturing',
                  status: m.status,
                  price:
                      '\$${m.wholesalePrice.toStringAsFixed(2)}/${m.unit ?? 'unit'}',
                  extras: [
                    if (m.moq != null) 'MOQ: ${m.moq}',
                    if (m.leadTimeDays != null)
                      'Lead: ${m.leadTimeDays}d',
                    if (m.isLocallyMade) 'Local',
                  ],
                  onTap: () => ctx.go('/manufacturing/${m.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
