import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';
import '../../widgets/image_gallery.dart';

final _propertyDetailProvider =
    FutureProvider.autoDispose.family<PropertyModel, int>((ref, id) async {
  final data = await ref.read(apiServiceProvider).getProperty(id);
  return PropertyModel.fromJson(data);
});

final _propertyImagesProvider =
    FutureProvider.autoDispose.family<List<String>, int>((ref, id) async {
  return ref.read(apiServiceProvider).getPropertyImageUrls(id);
});


class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_propertyDetailProvider(id));
    final imagesAsync = ref.watch(_propertyImagesProvider(id));
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Property Detail'),
        leading: IconButton(
          icon: Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (p) => _PropertyDetailBody(
          property: p,
          imageUrls: imagesAsync.valueOrNull ?? const [],
        ),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (p) => _BottomBar(property: p),
        orElse: () => null,
      ),
    );
  }
}

class _PropertyDetailBody extends StatelessWidget {
  const _PropertyDetailBody({required this.property, required this.imageUrls});
  final PropertyModel property;
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final p = property;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image gallery ────────────────────────────────────────────────
          ImageGallery(
            imageUrls: imageUrls.isEmpty ? null : imageUrls,
            height: 280,
            placeholderIcon: Icons.apartment_rounded,
            placeholderColor:
                Theme.of(context).colorScheme.primaryContainer,
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title + status ──────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    _StatusBadge(status: p.status),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Location ────────────────────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        p.city != null ? '${p.city}, ${p.address}' : p.address,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Price ────────────────────────────────────────────────────
                Text(
                  '\$${p.price.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // ── Spec chips ───────────────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (p.bedrooms != null)
                      _SpecChip(icon: Icons.bed_outlined, label: '${p.bedrooms} Beds'),
                    if (p.bathrooms != null)
                      _SpecChip(icon: Icons.bathtub_outlined, label: '${p.bathrooms} Baths'),
                    if (p.areaSqft != null)
                      _SpecChip(icon: Icons.square_foot, label: '${p.areaSqft} sqft'),
                    _SpecChip(
                        icon: Icons.category_outlined,
                        label: p.propertyType.toUpperCase()),
                  ],
                ),

                // ── Description ──────────────────────────────────────────────
                if (p.description != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text('About this property',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(p.description!,
                      style: TextStyle(
                          color: Colors.grey[700], height: 1.5, fontSize: 14)),
                ],

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.property});
  final PropertyModel property;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.favorite_border),
                label: const Text('Save'),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Contact Agent'),
                onPressed: () {},
              ),
            ),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'available'
        ? const Color(0xFF2E7D32)
        : status == 'sold'
            ? Colors.red[700]!
            : Colors.orange[700]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
