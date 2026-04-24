import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';

final _propertyDetailProvider =
    FutureProvider.autoDispose.family<PropertyModel, int>((ref, id) async {
  final data = await ref.read(apiServiceProvider).getProperty(id);
  return PropertyModel.fromJson(data);
});

class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_propertyDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Property Detail')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (p) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  // FIX: withOpacity deprecated → withValues(alpha:)
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Icon(
                    Icons.home,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      p.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.status == 'available'
                          ? Colors.green
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      p.status.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      p.city != null
                          ? '${p.city}, ${p.address}'
                          : p.address,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '\$${p.price.toStringAsFixed(0)}',
                style:
                    Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (p.bedrooms != null)
                    _SpecChip(
                        icon: Icons.bed,
                        label: '${p.bedrooms} Bedrooms'),
                  if (p.bathrooms != null)
                    _SpecChip(
                        icon: Icons.bathtub,
                        label: '${p.bathrooms} Bathrooms'),
                  if (p.areaSqft != null)
                    _SpecChip(
                        icon: Icons.square_foot,
                        label: '${p.areaSqft} sqft'),
                  _SpecChip(
                      icon: Icons.category,
                      label: p.propertyType.toUpperCase()),
                ],
              ),
              if (p.description != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(p.description!),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.chat),
            label: const Text('Contact Agent'),
            onPressed: () {},
          ),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}
