import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/image_gallery.dart';
import '../../widgets/listing_widgets.dart';
import '../../widgets/promote_listing_button.dart';

final _mfgDetailProvider =
    FutureProvider.autoDispose.family<ManufacturingProductModel, int>(
        (ref, id) async {
  final data =
      await ref.read(apiServiceProvider).getManufacturingProduct(id);
  return ManufacturingProductModel.fromJson(data);
});

class ManufacturingDetailScreen extends ConsumerStatefulWidget {
  const ManufacturingDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ManufacturingDetailScreen> createState() => _ManufacturingDetailScreenState();
}

class _ManufacturingDetailScreenState extends ConsumerState<ManufacturingDetailScreen> {
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
      final saved = await api.checkSaved(userId: userId, itemType: 'manufacturing', itemId: widget.id);
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
        await api.unsaveItem(userId: userId, itemType: 'manufacturing', itemId: widget.id);
      } else {
        await api.saveItem(userId: userId, itemType: 'manufacturing', itemId: widget.id);
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

  Future<void> _contactAgent(ManufacturingProductModel m) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    if (m.tenantId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No seller contact available for this product.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      final api = ref.read(apiServiceProvider);
      final tenantData = await api.getTenant(m.tenantId!);
      final recipientId = tenantData['owner_user_id'] as int?;
      if (recipientId == null || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seller contact not available.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final convId = await api.findOrCreateConversation(
        initiatorId: userId,
        recipientId: recipientId,
        subject: 'Re: ${m.title}',
      );
      if (mounted) context.push('/messages/$convId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start conversation: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(ManufacturingProductModel m) async {
    const statuses = ['available', 'out_of_stock', 'discontinued'];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Update Status'),
        children: statuses
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(s),
                  child: Text(s, style: TextStyle(
                    fontWeight: s == m.status ? FontWeight.bold : FontWeight.normal,
                  )),
                ))
            .toList(),
      ),
    );
    if (picked == null || picked == m.status || !mounted) return;
    try {
      await ref.read(apiServiceProvider).patchMfgStatus(m.id, picked);
      ref.invalidate(_mfgDetailProvider(widget.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _requestQuote(ManufacturingProductModel m) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _RfqDialog(
        title: m.title,
        unit: m.unit,
        tenantId: m.tenantId,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(apiServiceProvider).createRFQ({
        'title': 'Quote request for ${m.title}',
        'description': result['notes'] as String?,
        'quantity': result['quantity'] as double?,
        'unit': m.unit,
        'category': 'manufacturing',
        'buyer_id': userId,
        if (m.tenantId != null) 'seller_tenant_id': m.tenantId,
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

  Future<void> _orderNow(ManufacturingProductModel m) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    if (m.tenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product has no seller – cannot place order.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _OrderDialog(
        title: m.title,
        unitPrice: m.wholesalePrice,
        unit: m.unit,
      ),
    );
    if (result == null || !mounted) return;
    final qty = result['quantity'] as double? ?? 1.0;
    try {
      await ref.read(apiServiceProvider).createOrder({
        'seller_tenant_id': m.tenantId,
        'buyer_user_id': userId,
        'delivery_address': result['address'] as String?,
        'notes': result['notes'] as String?,
        'items': [
          {
            'manufacturing_product_id': m.id,
            'quantity': qty,
            'unit_price': m.wholesalePrice,
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
    final async = ref.watch(_mfgDetailProvider(widget.id));
    final auth = ref.watch(authProvider);
    final isOwner = auth.isAuthenticated &&
        (auth.role == 'company' ||
            auth.role == 'organization' ||
            auth.role == 'agent');
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
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isOwner)
            async.maybeWhen(
              data: (m) => Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 18),
                  onPressed: () => _updateStatus(m),
                  tooltip: 'Update status',
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
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
        data: (m) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageGallery(
                imageUrls: m.images,
                height: 240,
                placeholderIcon: Icons.precision_manufacturing_rounded,
                placeholderColor: const Color(0xFFFFE0B2),
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
                    const SizedBox(height: 10),
                    Text(
                      '\$${m.wholesalePrice.toStringAsFixed(2)} / ${m.unit ?? 'unit'}',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (m.category != null) _InfoChip(label: m.category!),
                        if (m.location != null)
                          _InfoChip(
                              label: '📍 ${m.location!}',
                              bgColor: Colors.blue.withValues(alpha: 0.08),
                              textColor: Colors.blue[700]!),
                        if (m.sku != null)
                          _InfoChip(label: 'Product Code: ${m.sku}'),
                        if (m.moq != null)
                          _InfoChip(
                              label:
                                  'Min Order: ${m.moq} ${m.unit ?? ''}'),
                        if (m.quantityAvailable != null)
                          _InfoChip(label: 'In Stock: ${m.quantityAvailable}'),
                        if (m.leadTimeDays != null)
                          _InfoChip(
                              label:
                                  'Processing time: ${m.leadTimeDays} days'),
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
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Certifications',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: m.certifications!
                            .map((c) => _InfoChip(
                                  label: '✓ $c',
                                  bgColor: Colors.green.withValues(alpha: 0.1),
                                  textColor: const Color(0xFF2E7D32),
                                ))
                            .toList(),
                      ),
                    ],
                    // ── Listing code ────────────────────────────────────────
                    if (m.listingCode != null) ...[
                      const SizedBox(height: 12),
                      ListingCodeBadge(code: m.listingCode!),
                    ],
                    if (m.description != null) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Description',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(m.description!,
                          style: TextStyle(
                              color: Colors.grey[700], height: 1.5)),
                    ],
                    // ── Owner / company / org profile ────────────────────────
                    if (m.ownerProfile != null) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Seller',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ListingOwnerCard(owner: m.ownerProfile!),
                    ],
                    if (m.latitude != null && m.longitude != null) ...[
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
                            lat: m.latitude!,
                            lng: m.longitude!,
                            label: m.title,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 96),
                    // Promote button for owners
                    if (isOwner)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          PromoteListingButton(
                            listingType: 'manufacturing',
                            listingId: m.id,
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (m) => Container(
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
                  icon: const Icon(Icons.request_quote_outlined, size: 16),
                  label: const Text('Quote'),
                  onPressed: () => _requestQuote(m),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  icon: const Icon(Icons.message_outlined, size: 16),
                  label: const Text('Contact'),
                  onPressed: () => _contactAgent(m),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                  label: const Text('Order'),
                  onPressed: () => _orderNow(m),
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
                child: const Icon(
                  Icons.location_pin,
                  color: Color(0xFFE65100),
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
