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
        onPressed: () => context.go('/manufacturing/create'),
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
                  Icon(Icons.precision_manufacturing_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No products listed yet.',
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Product'),
                    onPressed: () => context.go('/manufacturing/create'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_mfgListProvider),
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
                final m = items[i];
                final imgUrl =
                    (m.images != null && m.images!.isNotEmpty)
                        ? m.images!.first
                        : null;
                return ListingCard(
                  icon: Icons.precision_manufacturing_rounded,
                  iconColor: const Color(0xFFE65100),
                  imageUrl: imgUrl,
                  title: m.title,
                  subtitle:
                      m.location ?? m.category ?? (m.isLocallyMade ? 'Locally Made' : ''),
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
