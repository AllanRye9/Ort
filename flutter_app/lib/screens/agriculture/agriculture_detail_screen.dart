import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
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

  Future<void> _requestQuote(AgricultureListingModel a) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _RfqDialog(
        title: a.title,
        unit: a.unit,
        tenantId: a.tenantId,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(apiServiceProvider).createRFQ({
        'title': 'Quote request for ${a.title}',
        'description': result['notes'] as String?,
        'quantity': result['quantity'] as double?,
        'unit': a.unit,
        'category': 'agriculture',
        'buyer_id': userId,
        if (a.tenantId != null) 'seller_tenant_id': a.tenantId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote request submitted!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit quote: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _orderNow(AgricultureListingModel a) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    if (a.tenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This listing has no seller – cannot place order.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _OrderDialog(
        title: a.title,
        unitPrice: a.pricePerUnit,
        unit: a.unit,
      ),
    );
    if (result == null || !mounted) return;
    final qty = result['quantity'] as double? ?? 1.0;
    try {
      await ref.read(apiServiceProvider).createOrder({
        'seller_tenant_id': a.tenantId,
        'buyer_user_id': userId,
        'delivery_address': result['address'] as String?,
        'notes': result['notes'] as String?,
        'items': [
          {
            'agriculture_listing_id': a.id,
            'quantity': qty,
            'unit_price': a.pricePerUnit,
          }
        ],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed! Check Orders for status.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
                height: 240,
                placeholderIcon: Icons.grass_rounded,
                placeholderColor: const Color(0xFFC8E6C9),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                      const SizedBox(height: 4),
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
                    const SizedBox(height: 10),
                    Text(
                      '\$${a.pricePerUnit.toStringAsFixed(2)} / ${a.unit ?? 'unit'}',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
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
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Storage Conditions',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(a.storageConditions!,
                          style: TextStyle(
                              color: Colors.grey[700], height: 1.5)),
                    ],
                    if (a.description != null) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Description',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(a.description!,
                          style: TextStyle(
                              color: Colors.grey[700], height: 1.5)),
                    ],
                    if (a.latitude != null && a.longitude != null) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Location',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 180,
                          child: _LocationMap(
                            lat: a.latitude!,
                            lng: a.longitude!,
                            label: a.title,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (a) => Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
                  onPressed: () => _requestQuote(a),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Order Now'),
                  onPressed: () => _orderNow(a),
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

// ─── RFQ dialog ──────────────────────────────────────────────────────────────

class _RfqDialog extends StatefulWidget {
  const _RfqDialog({required this.title, this.unit, this.tenantId});
  final String title;
  final String? unit;
  final int? tenantId;

  @override
  State<_RfqDialog> createState() => _RfqDialogState();
}

class _RfqDialogState extends State<_RfqDialog> {
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Request Quote'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('for ${widget.title}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity${widget.unit != null ? ' (${widget.unit})' : ''}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes / requirements',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop({
                'quantity': double.tryParse(_qtyCtrl.text),
                'notes': _notesCtrl.text.trim(),
              });
            },
            child: const Text('Submit'),
          ),
        ],
      );
}

// ─── Order dialog ─────────────────────────────────────────────────────────────

class _OrderDialog extends StatefulWidget {
  const _OrderDialog({
    required this.title,
    required this.unitPrice,
    this.unit,
  });
  final String title;
  final double unitPrice;
  final String? unit;

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _addrCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _addrCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(_qtyCtrl.text) ?? 1.0;
    final total = qty * widget.unitPrice;
    return AlertDialog(
      title: const Text('Place Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Quantity${widget.unit != null ? ' (${widget.unit})' : ''}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Total: \$${total.toStringAsFixed(2)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addrCtrl,
              decoration: const InputDecoration(
                labelText: 'Delivery address',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your order will be reviewed by the seller. You will be notified when confirmed.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'quantity': double.tryParse(_qtyCtrl.text) ?? 1.0,
              'address': _addrCtrl.text.trim(),
              'notes': _notesCtrl.text.trim(),
            });
          },
          child: const Text('Place Order'),
        ),
      ],
    );
  }
}

// ─── Location map ─────────────────────────────────────────────────────────────

class _LocationMap extends StatelessWidget {
  const _LocationMap({required this.lat, required this.lng, required this.label});
  final double lat;
  final double lng;
  final String label;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ort.marketplace',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 40,
              height: 40,
              child: Tooltip(
                message: label,
                child: Icon(
                  Icons.location_pin,
                  color: const Color(0xFF2E7D32),
                  size: 40,
                ),
              ),
            ),
          ],
        ),
      ],
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
