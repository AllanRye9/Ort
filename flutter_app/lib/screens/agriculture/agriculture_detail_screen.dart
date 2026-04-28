import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/image_gallery.dart';

final _agriDetailProvider =
    FutureProvider.autoDispose.family<AgricultureListingModel, int>(
        (ref, id) async {
  final data = await ref.read(apiServiceProvider).getAgricultureListing(id);
  return AgricultureListingModel.fromJson(data);
});

class AgricultureDetailScreen extends ConsumerStatefulWidget {
  const AgricultureDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<AgricultureDetailScreen> createState() => _AgricultureDetailScreenState();
}

class _AgricultureDetailScreenState extends ConsumerState<AgricultureDetailScreen> {
  bool _isSaved = false;
  bool _saveBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    try {
      final api = ref.read(apiServiceProvider);
      final userId = ref.read(authProvider).userId;
      if (userId == null) return;
      final saved = await api.checkSaved(userId: userId, itemType: 'agriculture', itemId: widget.id);
      if (mounted) setState(() => _isSaved = saved);
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (_saveBusy) return;
    setState(() => _saveBusy = true);
    try {
      final api = ref.read(apiServiceProvider);
      final userId = ref.read(authProvider).userId;
      if (userId == null) return;
      if (_isSaved) {
        await api.unsaveItem(userId: userId, itemType: 'agriculture', itemId: widget.id);
      } else {
        await api.saveItem(userId: userId, itemType: 'agriculture', itemId: widget.id);
      }
      if (mounted) setState(() => _isSaved = !_isSaved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saveBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_agriDetailProvider(widget.id));
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Commodity Detail'),
        leading: IconButton(
          icon: Container(
            decoration: const BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: _saveBusy
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.white,
                    ),
                    onPressed: _toggleSave,
                    tooltip: _isSaved ? 'Unsave' : 'Save',
                  ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (a) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageGallery(
                imageUrls: a.images,
                height: 260,
                placeholderIcon: Icons.grass_rounded,
                placeholderColor: const Color(0xFFC8E6C9),
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
                            a.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(
                            status: a.status,
                            color: const Color(0xFF2E7D32)),
                      ],
                    ),
                    if (a.location != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.location_on_outlined,
                            size: 16,
                            color: const Color(0xFF388E3C)),
                        const SizedBox(width: 4),
                        Text(a.location!,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14)),
                      ]),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '\$${a.pricePerUnit.toStringAsFixed(2)} / ${a.unit ?? 'unit'}',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (a.category != null)
                          _InfoChip(label: a.category!),
                        if (a.qualityGrade != null)
                          _InfoChip(label: 'Grade: ${a.qualityGrade}'),
                        if (a.moq != null)
                          _InfoChip(
                              label:
                                  'MOQ: ${a.moq} ${a.unit ?? ''}'),
                        if (a.quantityAvailable != null)
                          _InfoChip(
                              label:
                                  'Available: ${a.quantityAvailable} ${a.unit ?? ''}'),
                        if (a.isPerishable)
                          _InfoChip(
                              label: '⚠ Perishable',
                              bgColor: Colors.orange.withValues(alpha: 0.1),
                              textColor: Colors.orange[700]!),
                        if (a.certification != null)
                          _InfoChip(label: '✓ ${a.certification}'),
                      ],
                    ),
                    if (a.storageConditions != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text('Storage Conditions',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(a.storageConditions!,
                          style: TextStyle(
                              color: Colors.grey[700], height: 1.5)),
                    ],
                    if (a.description != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text('Description',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(a.description!,
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
  const _StatusBadge({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700),
        ),
      );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    this.bgColor,
    this.textColor,
  });
  final String label;
  final Color? bgColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor ??
              Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor ??
                Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
}
