import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';

final _mfgDetailProvider =
    FutureProvider.autoDispose.family<ManufacturingProductModel, int>(
        (ref, id) async {
  final data =
      await ref.read(apiServiceProvider).getManufacturingProduct(id);
  return ManufacturingProductModel.fromJson(data);
});

class ManufacturingDetailScreen extends ConsumerWidget {
  const ManufacturingDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_mfgDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Product Detail')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (m) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.orange.withOpacity(0.1),
                ),
                child: const Center(
                    child:
                        Icon(Icons.factory, size: 72, color: Colors.orange)),
              ),
              const SizedBox(height: 16),
              Text(
                m.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${m.wholesalePrice.toStringAsFixed(2)} / ${m.unit ?? 'unit'}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (m.category != null) Chip(label: Text(m.category!)),
                  if (m.sku != null) Chip(label: Text('SKU: ${m.sku}')),
                  if (m.moq != null)
                    Chip(label: Text('MOQ: ${m.moq} ${m.unit ?? ''}')),
                  if (m.quantityAvailable != null)
                    Chip(label: Text('Stock: ${m.quantityAvailable}')),
                  if (m.leadTimeDays != null)
                    Chip(label: Text('Lead time: ${m.leadTimeDays} days')),
                  if (m.isLocallyMade)
                    Chip(
                      label: const Text('Locally Made'),
                      avatar: const Icon(Icons.verified, size: 14),
                    ),
                  if (m.countryOfOrigin != null)
                    Chip(label: Text(m.countryOfOrigin!)),
                ],
              ),
              if (m.certifications != null &&
                  m.certifications!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Certifications',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: m.certifications!
                      .map((c) => Chip(
                            label: Text(c),
                            backgroundColor: Colors.green.withOpacity(0.1),
                          ))
                      .toList(),
                ),
              ],
              if (m.description != null) ...[
                const SizedBox(height: 16),
                const Text('Description',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(m.description!),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.request_quote),
                  label: const Text('Request Quote'),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Order Now'),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        orElse: () => null,
      ),
    );
  }
}
