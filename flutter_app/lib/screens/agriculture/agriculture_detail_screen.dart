import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';

final _agriDetailProvider =
    FutureProvider.autoDispose.family<AgricultureListingModel, int>(
        (ref, id) async {
  final data = await ref.read(apiServiceProvider).getAgricultureListing(id);
  return AgricultureListingModel.fromJson(data);
});

class AgricultureDetailScreen extends ConsumerWidget {
  const AgricultureDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_agriDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Commodity Detail')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (a) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.green.withOpacity(0.1),
                ),
                child: const Center(
                    child: Icon(Icons.grass, size: 72, color: Colors.green)),
              ),
              const SizedBox(height: 16),
              Text(
                a.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (a.location != null)
                Row(children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(a.location!, style: const TextStyle(color: Colors.grey)),
                ]),
              const SizedBox(height: 12),
              Text(
                '\$${a.pricePerUnit.toStringAsFixed(2)} / ${a.unit ?? 'unit'}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (a.category != null) Chip(label: Text(a.category!)),
                  if (a.qualityGrade != null)
                    Chip(label: Text('Grade: ${a.qualityGrade}')),
                  if (a.moq != null)
                    Chip(label: Text('MOQ: ${a.moq} ${a.unit ?? ''}')),
                  if (a.quantityAvailable != null)
                    Chip(
                        label: Text(
                            'Available: ${a.quantityAvailable} ${a.unit ?? ''}')),
                  if (a.isPerishable)
                    Chip(
                      label: const Text('Perishable'),
                      avatar: const Icon(Icons.warning, size: 14),
                    ),
                  if (a.certification != null)
                    Chip(label: Text(a.certification!)),
                ],
              ),
              if (a.storageConditions != null) ...[
                const SizedBox(height: 16),
                const Text('Storage Conditions',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(a.storageConditions!),
              ],
              if (a.description != null) ...[
                const SizedBox(height: 16),
                const Text('Description',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(a.description!),
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
