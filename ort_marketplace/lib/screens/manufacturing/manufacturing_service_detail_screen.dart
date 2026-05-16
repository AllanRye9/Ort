import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api_service.dart';
import '../../core/app_preferences.dart';
import '../../core/auth_provider.dart';
import '../../core/listing_providers.dart';
import '../../models/models.dart';
import '../../widgets/image_gallery.dart';

final _svcDetailProvider =
    FutureProvider.autoDispose.family<ManufacturingServiceModel, int>(
        (ref, id) async {
  final data = await ref.read(apiServiceProvider).getManufacturingService(id);
  return ManufacturingServiceModel.fromJson(data);
});

class ManufacturingServiceDetailScreen extends ConsumerStatefulWidget {
  const ManufacturingServiceDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ManufacturingServiceDetailScreen> createState() =>
      _ManufacturingServiceDetailScreenState();
}

class _ManufacturingServiceDetailScreenState
    extends ConsumerState<ManufacturingServiceDetailScreen> {
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
      // Services share the manufacturing saved-item type for now
      final saved = await api.checkSaved(
          userId: userId,
          itemType: 'manufacturing',
          itemId: widget.id);
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
        await api.unsaveItem(
            userId: userId,
            itemType: 'manufacturing',
            itemId: widget.id);
      } else {
        await api.saveItem(
            userId: userId,
            itemType: 'manufacturing',
            itemId: widget.id);
      }
      if (mounted) setState(() => _isSaved = !_isSaved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saveBusy = false);
    }
  }

  Future<void> _contactProvider(ManufacturingServiceModel s) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to contact the provider.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (s.tenantId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No contact available for this service.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      final api = ref.read(apiServiceProvider);
      final tenantData = await api.getTenant(s.tenantId!);
      final recipientId = tenantData['owner_user_id'] as int?;
      if (recipientId == null || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service provider contact not available.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final convId = await api.findOrCreateConversation(
        initiatorId: userId,
        recipientId: recipientId,
        subject: 'Enquiry about: ${s.title}',
      );
      await api.sendMessage({
        'conversation_id': convId,
        'sender_id': userId,
        'body': 'Contact request about service "${s.title}"${s.location != null ? ' at ${s.location}' : ''}.',
        'message_type': 'text',
      });
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

  Future<void> _deleteListing(ManufacturingServiceModel s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Delete "${s.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(apiServiceProvider).deleteManufacturingService(s.id);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _updateStatus(ManufacturingServiceModel s) async {
    const statuses = ['available', 'fully_booked', 'discontinued'];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Update Status'),
        children: statuses
            .map((st) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(st),
                  child: Text(
                    st.replaceAll('_', ' ')[0].toUpperCase() +
                        st.replaceAll('_', ' ').substring(1),
                    style: TextStyle(
                      fontWeight:
                          st == s.status ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
    if (picked == null || picked == s.status || !mounted) return;
    try {
      await ref
          .read(apiServiceProvider)
          .patchMfgServiceStatus(s.id, picked);
      ref.invalidate(_svcDetailProvider(widget.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update status: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_svcDetailProvider(widget.id));
    final auth = ref.watch(authProvider);
    final mode = ref.watch(marketplaceModeProvider);
    final userCountry = ref.watch(userCountryProvider);
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
        title: const Text('Service Detail'),
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
              data: (s) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 18),
                      onPressed: () => _updateStatus(s),
                      tooltip: 'Update status',
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white, size: 18),
                      onPressed: () => _deleteListing(s),
                      tooltip: 'Delete service',
                    ),
                  ),
                ],
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
        data: (s) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageGallery(
                imageUrls: s.images,
                height: 240,
                placeholderIcon: Icons.build_rounded,
                placeholderColor: const Color(0xFFBBDEFB),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title & status ───────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            s.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: s.status),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Price ────────────────────────────────────────
                    Text(
                      '${formatCurrencyForMode(s.price, currency: s.currency, viewerCountry: userCountry, decimals: 2, mode: mode)}'
                      '${s.pricingUnit != null ? ' / ${s.pricingUnit!.replaceAll('_', ' ')}' : ''}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            color: const Color(0xFF1565C0),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // ── Info chips ────────────────────────────────────
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (s.serviceType != null)
                          _InfoChip(
                            label: s.serviceType![0].toUpperCase() +
                                s.serviceType!.substring(1),
                          ),
                        _InfoChip(
                          label: s.pricingType == 'fixed'
                              ? 'Fixed Price'
                              : 'Negotiable',
                        ),
                        if (s.location != null)
                          _InfoChip(
                            label: '📍 ${s.location!}',
                            bgColor: Colors.blue.withValues(alpha: 0.08),
                            textColor: Colors.blue[700]!,
                          ),
                        if (s.minOrderValue != null)
                          _InfoChip(
                            label:
                                'Min job: \$${s.minOrderValue!.toStringAsFixed(0)}',
                          ),
                        if (s.noticePeriodDays != null)
                          _InfoChip(
                            label:
                                '${s.noticePeriodDays} day notice required',
                          ),
                      ],
                    ),

                    // ── Certifications ────────────────────────────────
                    if (s.certifications != null &&
                        s.certifications!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Certifications & Qualifications',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: s.certifications!
                            .map((c) => _InfoChip(
                                  label: '✓ $c',
                                  bgColor:
                                      Colors.green.withValues(alpha: 0.1),
                                  textColor: const Color(0xFF2E7D32),
                                ))
                            .toList(),
                      ),
                    ],

                    // ── Description ───────────────────────────────────
                    if (s.description != null) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'About this service',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.description!,
                        style:
                            TextStyle(color: Colors.grey[700], height: 1.5),
                      ),
                    ],

                    // ── Map ───────────────────────────────────────────
                    if (s.latitude != null && s.longitude != null) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Location',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 180,
                          child: _LocationMap(
                            lat: s.latitude!,
                            lng: s.longitude!,
                            label: s.title,
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
        data: (s) => Container(
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
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  icon: const Icon(Icons.message_outlined, size: 16),
                  label: const Text('Contact Provider'),
                  onPressed: () => _contactProvider(s),
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

// ─── Reusable chips ──────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor ??
              Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  Color _color() {
    switch (status) {
      case 'available':
        return const Color(0xFF2E7D32);
      case 'fully_booked':
        return Colors.orange[700]!;
      case 'discontinued':
        return Colors.red[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color(),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      );
}

// ─── Location map ─────────────────────────────────────────────────────────────

class _LocationMap extends StatelessWidget {
  const _LocationMap(
      {required this.lat, required this.lng, required this.label});

  final double lat;
  final double lng;
  final String label;

  @override
  Widget build(BuildContext context) => FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lng),
          initialZoom: 14,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.ort_marketplace',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                child: Icon(Icons.location_pin,
                    color: Theme.of(context).colorScheme.primary, size: 40),
              ),
            ],
          ),
        ],
      );
}
