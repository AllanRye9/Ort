import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';
import '../../widgets/image_gallery.dart';

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Product Detail'),
        leading: IconButton(
          icon: Container(
            decoration: const BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (m) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageGallery(
                imageUrls: m.images,
                height: 260,
                placeholderIcon: Icons.precision_manufacturing_rounded,
                placeholderColor: const Color(0xFFFFE0B2),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            m.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: m.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '\$${m.wholesalePrice.toStringAsFixed(2)} / ${m.unit ?? 'unit'}',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (m.category != null) _InfoChip(label: m.category!),
                        if (m.sku != null)
                          _InfoChip(label: 'SKU: ${m.sku}'),
                        if (m.moq != null)
                          _InfoChip(
                              label:
                                  'MOQ: ${m.moq} ${m.unit ?? ''}'),
                        if (m.quantityAvailable != null)
                          _InfoChip(label: 'Stock: ${m.quantityAvailable}'),
                        if (m.leadTimeDays != null)
                          _InfoChip(
                              label:
                                  'Lead time: ${m.leadTimeDays} days'),
                        if (m.isLocallyMade)
                          _InfoChip(
                              label: '✓ Locally Made',
                              bgColor: Colors.green.withValues(alpha: 0.1),
                              textColor: const Color(0xFF2E7D32)),
                        if (m.countryOfOrigin != null)
                          _InfoChip(label: m.countryOfOrigin!),
                      ],
                    ),
                    if (m.certifications != null &&
                        m.certifications!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text('Certifications',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: m.certifications!
                            .map((c) => _InfoChip(
                                  label: '✓ $c',
                                  bgColor: Colors.green.withValues(alpha: 0.1),
                                  textColor: const Color(0xFF2E7D32),
                                ))
                            .toList(),
                      ),
                    ],
                    if (m.description != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text('Description',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(m.description!,
                          style: TextStyle(
                              color: Colors.grey[700], height: 1.5)),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (_) => Container(
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
                  icon: const Icon(Icons.request_quote_outlined),
                  label: const Text('Request Quote'),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_cart_outlined),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'available'
        ? const Color(0xFF2E7D32)
        : status == 'out_of_stock'
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
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.bgColor, this.textColor});
  final String label;
  final Color? bgColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor ??
              Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              color: textColor ?? Theme.of(context).colorScheme.onSurface),
        ),
      );
}
