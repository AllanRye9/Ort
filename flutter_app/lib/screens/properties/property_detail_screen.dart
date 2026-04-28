import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/image_gallery.dart';

final _propertyDetailProvider =
    FutureProvider.autoDispose.family<PropertyModel, int>((ref, id) async {
  final data = await ref.read(apiServiceProvider).getProperty(id);
  return PropertyModel.fromJson(data);
});


class PropertyDetailScreen extends ConsumerStatefulWidget {
  const PropertyDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
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
      final saved = await api.checkSaved(userId: userId, itemType: 'property', itemId: widget.id);
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
        await api.unsaveItem(userId: userId, itemType: 'property', itemId: widget.id);
      } else {
        await api.saveItem(userId: userId, itemType: 'property', itemId: widget.id);
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

  Future<void> _contactAgent(PropertyModel p) async {
    final agentId = p.agentId;
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    if (agentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No agent assigned to this property.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Show consent dialog before starting conversation
    final consented = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact Agent'),
        content: const Text(
          'Starting a conversation will allow the agent to see your public profile '
          'information (name and contact details you have shared). Do you consent?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Contact Agent'),
          ),
        ],
      ),
    );
    if (consented != true || !mounted) return;

    try {
      final api = ref.read(apiServiceProvider);
      final convId = await api.findOrCreateConversation(
        initiatorId: userId,
        recipientId: agentId,
        subject: 'Re: ${p.title}',
        propertyId: p.id,
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_propertyDetailProvider(widget.id));
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Property Detail'),
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
        data: (p) => _PropertyDetailBody(property: p),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (p) => _BottomBar(
          isSaved: _isSaved,
          saveBusy: _saveBusy,
          onSave: _toggleSave,
          onContactAgent: () => _contactAgent(p),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _PropertyDetailBody extends StatelessWidget {
  const _PropertyDetailBody({required this.property});
  final PropertyModel property;

  @override
  Widget build(BuildContext context) {
    final p = property;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image gallery ─────────────────────────────────────────────────
          ImageGallery(
            imageUrls: p.imageUrls.isEmpty ? null : p.imageUrls,
            height: 260,
            placeholderIcon: Icons.apartment_rounded,
            placeholderColor: Theme.of(context).colorScheme.primaryContainer,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title + status ───────────────────────────────────────────
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
                const SizedBox(height: 6),

                // ── Location ─────────────────────────────────────────────────
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
                const SizedBox(height: 12),

                // ── Price ─────────────────────────────────────────────────────
                Text(
                  '\$${p.price.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                // ── Spec chips ────────────────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
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

                // ── Description ───────────────────────────────────────────────
                if (p.description != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('About this property',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(p.description!,
                      style: TextStyle(
                          color: Colors.grey[700], height: 1.5, fontSize: 14)),
                ],

                // ── Map ───────────────────────────────────────────────────────
                if (p.latitude != null && p.longitude != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Location',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 200,
                      child: _LocationMap(
                        lat: p.latitude!,
                        lng: p.longitude!,
                        label: p.title,
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
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.isSaved,
    required this.saveBusy,
    required this.onSave,
    required this.onContactAgent,
  });
  final bool isSaved;
  final bool saveBusy;
  final VoidCallback onSave;
  final VoidCallback onContactAgent;

  @override
  Widget build(BuildContext context) => Container(
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
            saveBusy
                ? const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton.outlined(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      semanticLabel: isSaved ? 'Unsave' : 'Save',
                    ),
                    onPressed: onSave,
                    tooltip: isSaved ? 'Unsave' : 'Save',
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Contact Agent'),
                onPressed: onContactAgent,
              ),
            ),
          ],
        ),
      );
}

class _LocationMap extends StatelessWidget {
  const _LocationMap({
    required this.lat,
    required this.lng,
    required this.label,
  });
  final double lat;
  final double lng;
  final String label;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: 14,
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
                  color: Theme.of(context).colorScheme.primary,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
