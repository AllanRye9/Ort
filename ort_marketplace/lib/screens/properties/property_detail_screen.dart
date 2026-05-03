import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/listing_providers.dart';
import '../../models/models.dart';
import '../../widgets/image_gallery.dart';
import '../../widgets/promote_listing_button.dart';

final _propertyDetailProvider =
    FutureProvider.autoDispose.family<PropertyModel, int>((ref, id) async {
  final data = await ref.read(apiServiceProvider).getProperty(id);
  return PropertyModel.fromJson(data);
});

final _propertyBidCountProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  return ref.read(apiServiceProvider).getPropertyBidCount(id);
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

  Future<void> _placeBid(PropertyModel p) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    // Derive currency from the property's country if available.
    final country = p.country?.toLowerCase();
    final currencySymbol = country == 'uganda'
        ? 'UGX '
        : country == 'united arab emirates'
            ? 'AED '
            : '\$';
    final currencyCode = country == 'uganda'
        ? 'UGX'
        : country == 'united arab emirates'
            ? 'AED'
            : 'USD';

    final bidCtrl =
        TextEditingController(text: p.price.toStringAsFixed(0));
    final notesCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Place Bid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.title,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: bidCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  labelText: 'Your bid amount ($currencyCode)',
                  prefixText: currencySymbol,
                  border: const OutlineInputBorder(),
                  helperText:
                      'Listed at $currencySymbol${p.price.toStringAsFixed(0)}',
                  isDense: true,
                ),
                onChanged: (_) => setDialog(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your bid will be reviewed by the agent.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final price =
                    double.tryParse(bidCtrl.text.trim());
                if (price == null || price <= 0) return;
                Navigator.of(ctx).pop({
                  'price': price,
                  'notes': notesCtrl.text.trim(),
                });
              },
              child: const Text('Submit Bid'),
            ),
          ],
        ),
      ),
    );
    bidCtrl.dispose();
    notesCtrl.dispose();
    if (result == null || !mounted) return;
    try {
      await ref.read(apiServiceProvider).createRFQ({
        'title': 'Bid on ${p.title}',
        'description': result['notes'] as String? ?? '',
        'category': 'property',
        'buyer_id': userId,
        'target_price': result['price'],
        'property_id': widget.id,
      });
      // Refresh the bid count displayed on the page.
      ref.invalidate(_propertyBidCountProvider(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Bid submitted! The agent will contact you via Messages.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bid failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(PropertyModel p) async {
    const statuses = ['available', 'sold', 'rented', 'pending', 'unavailable'];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Update Status'),
        children: statuses
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(s),
                  child: Text(s, style: TextStyle(
                    fontWeight: s == p.status ? FontWeight.bold : FontWeight.normal,
                  )),
                ))
            .toList(),
      ),
    );
    if (picked == null || picked == p.status || !mounted) return;
    try {
      await ref.read(apiServiceProvider).patchPropertyStatus(p.id, picked);
      ref.invalidate(_propertyDetailProvider(widget.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
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
    final auth = ref.watch(authProvider);
    final isOwner = auth.isAuthenticated &&
        (auth.role == 'agent' || auth.role == 'company' || auth.role == 'organization');
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
          if (isOwner)
            async.maybeWhen(
              data: (p) => Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 18),
                  onPressed: () => _updateStatus(p),
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
        data: (p) => _PropertyDetailBody(property: p),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (p) => _BottomBar(
          onBidNow: () => _placeBid(p),
          onContact: () => _contactAgent(p),
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
                  formatCurrency(p.price, country: p.country),
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
                    if (p.purpose != null)
                      _SpecChip(
                        icon: p.purpose == 'rent' ? Icons.key_outlined : Icons.sell_outlined,
                        label: p.purpose == 'rent' ? 'For Rent' : 'For Sale',
                      ),
                    if (p.landCategory != null)
                      _SpecChip(
                        icon: Icons.landscape_outlined,
                        label: '${p.landCategory![0].toUpperCase()}${p.landCategory!.substring(1)} Land',
                      ),
                    if (p.landAreaAcres != null)
                      _SpecChip(
                        icon: Icons.crop_square_outlined,
                        label: '${p.landAreaAcres!.toStringAsFixed(2)} acres',
                      ),
                    if (p.bedrooms != null)
                      _SpecChip(
                          icon: Icons.bed_outlined,
                          label: '${p.bedrooms} Bedroom${p.bedrooms! != 1 ? 's' : ''}'),
                    if (p.bathrooms != null)
                      _SpecChip(
                          icon: Icons.bathtub_outlined,
                          label: '${p.bathrooms} Bathroom${p.bathrooms! != 1 ? 's' : ''}'),
                    if (p.isUgandaMetric)
                      _SpecChip(
                        icon: Icons.square_foot,
                        label: '${p.plotLengthM!.toStringAsFixed(0)}m × '
                            '${p.plotWidthM!.toStringAsFixed(0)}m  '
                            '(${p.totalAreaM2!.toStringAsFixed(0)} m²)',
                      )
                    else if (p.areaSqft != null)
                      _SpecChip(icon: Icons.square_foot, label: '${p.areaSqft} sq ft'),
                    _SpecChip(
                        icon: Icons.category_outlined,
                        label: p.propertyType.toUpperCase()),
                    if (p.furnishing != null)
                      _SpecChip(
                        icon: Icons.chair_outlined,
                        label: p.furnishing!.replaceAll('_', ' ')
                            .split(' ')
                            .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1) : ''}')
                            .join(' '),
                      ),
                    if (p.floors != null)
                      _SpecChip(
                        icon: Icons.layers_outlined,
                        label: '${p.floors} Floor${p.floors! != 1 ? 's' : ''}',
                      ),
                    if (p.parkingSpaces != null)
                      _SpecChip(
                        icon: Icons.local_parking_outlined,
                        label: '${p.parkingSpaces} Parking',
                      ),
                    if (p.propertyAge != null)
                      _SpecChip(
                        icon: Icons.access_time_outlined,
                        label: '${p.propertyAge} yr${p.propertyAge! != 1 ? 's' : ''} old',
                      ),
                  ],
                ),
                // Uganda metric dimensions detail row
                if (p.isUgandaMetric) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Dimensions: ${p.plotLengthM!.toStringAsFixed(0)}m × '
                    '${p.plotWidthM!.toStringAsFixed(0)}m  |  '
                    'Total Area: ${p.totalAreaM2!.toStringAsFixed(0)} m²',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                // ── Building name ─────────────────────────────────────────────
                if (p.buildingName != null && p.buildingName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.business_outlined,
                          size: 15, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        p.buildingName!,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ],

                // ── Listing tracking code ──────────────────────────────────────
                if (p.listingCode != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.qr_code_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Listing Code: ',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.listingCode!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Bid count ─────────────────────────────────────────────────
                const SizedBox(height: 12),
                _AnimatedBidCount(propertyId: p.id),

                // ── Promote button (visible to authenticated non-buyers) ──────
                Consumer(
                  builder: (ctx, ref, _) {
                    final auth = ref.watch(authProvider);
                    final isPromoter = auth.isAuthenticated &&
                        (auth.role == 'agent' ||
                            auth.role == 'company' ||
                            auth.role == 'organization');
                    if (!isPromoter) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          PromoteListingButton(
                            listingType: 'property',
                            listingId: p.id,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // ── Amenities ─────────────────────────────────────────────────
                if (p.amenities != null && p.amenities!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Amenities',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: p.amenities!
                        .map((a) => Chip(
                              label: Text(a,
                                  style: const TextStyle(fontSize: 12)),
                              avatar: const Icon(
                                  Icons.check_circle_outline,
                                  size: 14),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ],

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

                // ── Agent / Company / Org profile ─────────────────────────────
                if (p.agentProfile != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _AgentProfileCard(agent: p.agentProfile!),
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

                // ── Reviews ───────────────────────────────────────────────────
                if (p.agentId != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _PropertyReviewsSection(
                    propertyId: p.id,
                    agentId: p.agentId!,
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

// ─── Agent / Company profile card ────────────────────────────────────────────

class _AgentProfileCard extends StatelessWidget {
  const _AgentProfileCard({required this.agent});
  final AgentProfileModel agent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String roleLabel = agent.role;
    if (roleLabel == 'agent') roleLabel = 'Agent';
    if (roleLabel == 'company') roleLabel = 'Company';
    if (roleLabel == 'organization') roleLabel = 'Organization';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Listed by $roleLabel',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: agent.avatarUrl != null
                      ? NetworkImage(agent.avatarUrl!)
                      : null,
                  child: agent.avatarUrl == null
                      ? Icon(Icons.person, size: 26, color: cs.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (agent.agencyName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          agent.agencyName!,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                      if (agent.phone != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 3),
                            Text(agent.phone!,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (agent.bio != null && agent.bio!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                agent.bio!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[700], height: 1.4),
              ),
            ],
            if (agent.licenseNumber != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.badge_outlined,
                      size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    'License: ${agent.licenseNumber}',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onBidNow,
    required this.onContact,
  });
  final VoidCallback onBidNow;
  final VoidCallback onContact;

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
            Expanded(
              child: FilledButton.tonal(
                onPressed: onContact,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 16),
                    SizedBox(width: 6),
                    Text('Chat'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.gavel_outlined, size: 16),
                label: const Text('Bid'),
                onPressed: onBidNow,
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

// ─── Animated bid count ────────────────────────────────────────────────────────

class _AnimatedBidCount extends ConsumerWidget {
  const _AnimatedBidCount({required this.propertyId});
  final int propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidAsync = ref.watch(_propertyBidCountProvider(propertyId));

    return bidAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (count) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: count.toDouble()),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
        builder: (context, value, _) {
          final cs = Theme.of(context).colorScheme;
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gavel_outlined,
                    size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  '${value.toInt()} Bid${value.toInt() != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Property reviews section ─────────────────────────────────────────────────

final _propertyReviewsProvider =
    FutureProvider.autoDispose.family<List<ReviewModel>, int>((ref, propertyId) async {
  final data = await ref.read(apiServiceProvider).getReviews(propertyId: propertyId);
  return data.map((e) => ReviewModel.fromJson(e as Map<String, dynamic>)).toList();
});

class _PropertyReviewsSection extends ConsumerStatefulWidget {
  const _PropertyReviewsSection({
    required this.propertyId,
    required this.agentId,
  });

  final int propertyId;
  final int agentId;

  @override
  ConsumerState<_PropertyReviewsSection> createState() =>
      _PropertyReviewsSectionState();
}

class _PropertyReviewsSectionState
    extends ConsumerState<_PropertyReviewsSection> {
  bool _showForm = false;
  int _draftRating = 5;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final reviewerId = ref.read(authProvider).userId;
      await ref.read(apiServiceProvider).createReview({
        'reviewed_agent_id': widget.agentId,
        'property_id': widget.propertyId,
        'rating': _draftRating,
        if (reviewerId != null) 'reviewer_id': reviewerId,
        if (_titleCtrl.text.trim().isNotEmpty) 'title': _titleCtrl.text.trim(),
        if (_bodyCtrl.text.trim().isNotEmpty) 'body': _bodyCtrl.text.trim(),
      });
      ref.invalidate(_propertyReviewsProvider(widget.propertyId));
      if (mounted) {
        setState(() {
          _showForm = false;
          _submitting = false;
          _titleCtrl.clear();
          _bodyCtrl.clear();
          _draftRating = 5;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(_propertyReviewsProvider(widget.propertyId));
    final authState = ref.watch(authProvider);
    final canReview =
        authState.isAuthenticated && authState.userId != widget.agentId;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Reviews',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (canReview && !_showForm)
              TextButton.icon(
                onPressed: () => setState(() => _showForm = true),
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: const Text('Write a review'),
              ),
          ],
        ),

        // Rating summary
        reviewsAsync.maybeWhen(
          data: (reviews) {
            if (reviews.isEmpty) return const SizedBox.shrink();
            final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                reviews.length;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 4),
                  Text(
                    avg.toStringAsFixed(1),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: cs.onSurface),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${reviews.length} review${reviews.length != 1 ? 's' : ''})',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 13),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),

        // Submit form
        if (_showForm) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Rating',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                      5,
                      (i) => GestureDetector(
                        onTap: () => setState(() => _draftRating = i + 1),
                        child: Icon(
                          i < _draftRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title (optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Your review (optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _showForm = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Review list
        reviewsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load reviews: $e',
              style: TextStyle(color: cs.error, fontSize: 12)),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No reviews yet.',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
                ),
              );
            }
            return Column(
              children: reviews
                  .map((r) => _ReviewCard(review: r))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.rating ? Icons.star : Icons.star_border,
                      size: 14,
                      color: Colors.amber[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (review.title != null && review.title!.isNotEmpty)
                  Expanded(
                    child: Text(
                      review.title!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            if (review.body != null && review.body!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                review.body!,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.4),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              review.createdAt.toLocal().toString().split(' ')[0],
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.45), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
