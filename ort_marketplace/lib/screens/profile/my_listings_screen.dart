import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/app_preferences.dart';
import '../../core/auth_provider.dart';
import '../../core/listing_providers.dart';
import '../../models/models.dart';

final _myListingsProvider =
    FutureProvider.autoDispose.family<List<PropertyModel>, int>((ref, agentId) async {
  final data = await ref.read(apiServiceProvider).getMyProperties(agentId: agentId);
  return data.map((j) => PropertyModel.fromJson(j as Map<String, dynamic>)).toList();
});

/// Returns the tenant owned by [userId], or null if none.
final _myTenantProvider =
    FutureProvider.autoDispose.family<TenantModel?, int>((ref, userId) async {
  final data = await ref.read(apiServiceProvider).getTenantByOwner(userId);
  if (data == null) return null;
  return TenantModel.fromJson(data);
});

typedef _AgriKey = ({int? tenantId, int? ownerUserId});
typedef _MfgKey = ({int? tenantId, int? ownerUserId});

final _myAgriListingsProvider =
    FutureProvider.autoDispose.family<List<AgricultureListingModel>, _AgriKey>((ref, key) async {
  if (key.tenantId == null && key.ownerUserId == null) return const [];
  final data = await ref
      .read(apiServiceProvider)
      .getAgricultureListings(
        tenantId: key.tenantId,
        ownerUserId: key.tenantId == null ? key.ownerUserId : null,
        limit: 200,
      );
  return data.map((j) => AgricultureListingModel.fromJson(j as Map<String, dynamic>)).toList();
});

final _myMfgListingsProvider =
    FutureProvider.autoDispose.family<List<ManufacturingProductModel>, _MfgKey>((ref, key) async {
  if (key.tenantId == null && key.ownerUserId == null) return const [];
  final data = await ref
      .read(apiServiceProvider)
      .getManufacturingProducts(
        tenantId: key.tenantId,
        ownerUserId: key.tenantId == null ? key.ownerUserId : null,
        limit: 200,
      );
  return data.map((j) => ManufacturingProductModel.fromJson(j as Map<String, dynamic>)).toList();
});

final _myMfgServicesProvider =
    FutureProvider.autoDispose.family<List<ManufacturingServiceModel>, _MfgKey>((ref, key) async {
  if (key.tenantId == null && key.ownerUserId == null) return const [];
  final data = await ref
      .read(apiServiceProvider)
      .getManufacturingServices(
        tenantId: key.tenantId,
        ownerUserId: key.tenantId == null ? key.ownerUserId : null,
        limit: 200,
      );
  return data.map((j) => ManufacturingServiceModel.fromJson(j as Map<String, dynamic>)).toList();
});

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    // Force a fresh fetch when the screen mounts (e.g., after creating a listing).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = ref.read(authProvider).userId;
      if (userId != null) ref.invalidate(_myListingsProvider(userId));
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(PropertyModel p) async {
    const statuses = ['available', 'sold', 'rented', 'pending', 'unavailable'];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change Status'),
        children: statuses
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(s),
                  child: Text(
                    s[0].toUpperCase() + s.substring(1),
                    style: TextStyle(
                      fontWeight:
                          s == p.status ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
    if (picked == null || picked == p.status || !mounted) return;
    try {
      await ref.read(apiServiceProvider).patchPropertyStatus(p.id, picked);
      final agentId = ref.read(authProvider).userId;
      if (agentId != null) ref.invalidate(_myListingsProvider(agentId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change status: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _deleteListing(PropertyModel p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text(
            'Delete "${p.title}"? This will soft-delete it; admins can restore it from the Deleted Items panel.'),
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
    setState(() => _deleting = true);
    try {
      await ref.read(apiServiceProvider).deleteProperty(p.id);
      final agentId = ref.read(authProvider).userId;
      if (agentId != null) ref.invalidate(_myListingsProvider(agentId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  static String _formatStatus(String s) =>
      s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

  Future<void> _changeAgriStatus(AgricultureListingModel a, _AgriKey key) async {
    // Agriculture supports 'reserved' (buyer hold); manufacturing does not.
    const statuses = ['available', 'sold_out', 'reserved', 'out_of_stock', 'discontinued'];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change Status'),
        children: statuses
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(s),
                  child: Text(
                    _formatStatus(s),
                    style: TextStyle(
                      fontWeight:
                          s == a.status ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
    if (picked == null || picked == a.status || !mounted) return;
    try {
      await ref.read(apiServiceProvider).patchAgriStatus(a.id, picked);
      ref.invalidate(_myAgriListingsProvider(key));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change status: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _changeMfgStatus(ManufacturingProductModel m, _MfgKey key) async {
    // Manufacturing does not use 'reserved'; products go directly to out_of_stock/discontinued.
    const statuses = ['available', 'sold_out', 'out_of_stock', 'discontinued'];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change Status'),
        children: statuses
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(s),
                  child: Text(
                    _formatStatus(s),
                    style: TextStyle(
                      fontWeight:
                          s == m.status ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
    if (picked == null || picked == m.status || !mounted) return;
    try {
      await ref.read(apiServiceProvider).patchMfgStatus(m.id, picked);
      ref.invalidate(_myMfgListingsProvider(key));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change status: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _deleteAgriListing(AgricultureListingModel a, _AgriKey key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text('Delete "${a.title}"?'),
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
    setState(() => _deleting = true);
    try {
      await ref.read(apiServiceProvider).deleteAgricultureListing(a.id);
      ref.invalidate(_myAgriListingsProvider(key));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _deleteMfgListing(ManufacturingProductModel m, _MfgKey key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text('Delete "${m.title}"?'),
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
    setState(() => _deleting = true);
    try {
      await ref.read(apiServiceProvider).deleteManufacturingProduct(m.id);
      ref.invalidate(_myMfgListingsProvider(key));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _changeMfgSvcStatus(ManufacturingServiceModel s, _MfgKey key) async {
    const statuses = ['available', 'fully_booked', 'discontinued'];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change Status'),
        children: statuses
            .map((st) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(st),
                  child: Text(
                    _formatStatus(st),
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
      await ref.read(apiServiceProvider).patchMfgServiceStatus(s.id, picked);
      ref.invalidate(_myMfgServicesProvider(key));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change status: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _deleteMfgService(ManufacturingServiceModel s, _MfgKey key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Delete "${s.title}"?'),
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
    setState(() => _deleting = true);
    try {
      await ref.read(apiServiceProvider).deleteManufacturingService(s.id);
      ref.invalidate(_myMfgServicesProvider(key));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).userId;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Listings')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    final tenantAsync = ref.watch(_myTenantProvider(userId));
    final tenantId = tenantAsync.valueOrNull?.id;
    final listingKey = (tenantId: tenantId, ownerUserId: userId);
    final mode = ref.watch(marketplaceModeProvider);
    final userCountry = ref.watch(userCountryProvider);

    final propertyListings = ref.watch(_myListingsProvider(userId));
    final agriListings = ref.watch(_myAgriListingsProvider(listingKey));
    final mfgListings = ref.watch(_myMfgListingsProvider(listingKey));
    final svcListings = ref.watch(_myMfgServicesProvider(listingKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6),
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.apartment_outlined), text: 'Properties'),
            Tab(icon: Icon(Icons.grass_outlined), text: 'Agriculture'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Products'),
            Tab(icon: Icon(Icons.build_outlined), text: 'Services'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            tooltip: 'Add Listing',
            onSelected: (route) => context.push(route),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: '/properties/create',
                  child: Text('Add Property')),
              PopupMenuItem(
                  value: '/agriculture/create',
                  child: Text('Add Agriculture')),
              PopupMenuItem(
                  value: '/manufacturing/create',
                  child: Text('Add Product or Service')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabCtrl,
            children: [
              // ── Properties tab ──────────────────────────────────────────
              propertyListings.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
                data: (listings) {
                  if (listings.isEmpty) {
                    return _EmptyState(
                      icon: Icons.apartment_outlined,
                      message: 'No property listings yet',
                      hint: 'Tap + to add your first property',
                      onAdd: () => context.push('/properties/create'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(_myListingsProvider(userId)),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: listings.length,
                      itemBuilder: (_, i) {
                        final p = listings[i];
                        return _PropertyListingCard(
                          property: p,
                          onView: () => context.push('/properties/${p.id}'),
                          onEdit: () => context.push('/properties/${p.id}/edit'),
                          onChangeStatus: () => _changeStatus(p),
                          onDelete: () => _deleteListing(p),
                        );
                      },
                    ),
                  );
                },
              ),

              // ── Agriculture tab ─────────────────────────────────────────
              agriListings.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
                data: (listings) {
                  if (listings.isEmpty) {
                    return _EmptyState(
                      icon: Icons.grass_outlined,
                      message: 'No agriculture listings yet',
                      hint: 'Tap + to add a commodity listing',
                      onAdd: () => context.push('/agriculture/create'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(_myAgriListingsProvider(listingKey)),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: listings.length,
                      itemBuilder: (_, i) {
                        final a = listings[i];
                        return _SimpleListingCard(
                          title: a.title,
                          subtitle: a.location ?? a.category ?? '',
                          price: '${formatCurrencyForMode(a.pricePerUnit, currency: a.currency, viewerCountry: userCountry, decimals: 2, mode: mode)} / ${a.unit ?? 'unit'}',
                          status: a.status,
                          imageUrl: a.images?.isNotEmpty == true
                              ? a.images!.first
                              : null,
                          placeholderIcon: Icons.grass,
                          onView: () =>
                              context.push('/agriculture/${a.id}'),
                          onEdit: () =>
                              context.push('/agriculture/${a.id}/edit'),
                          onChangeStatus: () =>
                              _changeAgriStatus(a, listingKey),
                          onDelete: () =>
                              _deleteAgriListing(a, listingKey),
                        );
                      },
                    ),
                  );
                },
              ),

              // ── Manufacturing Products tab ──────────────────────────────
              mfgListings.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
                data: (listings) {
                  if (listings.isEmpty) {
                    return _EmptyState(
                      icon: Icons.inventory_2_outlined,
                      message: 'No products listed yet',
                      hint: 'Tap + to add a product',
                      onAdd: () => context.push('/manufacturing/create'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(_myMfgListingsProvider(listingKey)),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: listings.length,
                      itemBuilder: (_, i) {
                        final m = listings[i];
                        return _SimpleListingCard(
                          title: m.title,
                          subtitle: m.location ?? m.category ?? '',
                          price: formatCurrencyForMode(m.wholesalePrice, currency: m.currency, viewerCountry: userCountry, decimals: 2, mode: mode),
                          status: m.status,
                          imageUrl: m.images?.isNotEmpty == true
                              ? m.images!.first
                              : null,
                          placeholderIcon:
                              Icons.precision_manufacturing,
                          onView: () =>
                              context.push('/manufacturing/${m.id}'),
                          onEdit: () =>
                              context.push('/manufacturing/${m.id}/edit'),
                          onChangeStatus: () =>
                              _changeMfgStatus(m, listingKey),
                          onDelete: () =>
                              _deleteMfgListing(m, listingKey),
                        );
                      },
                    ),
                  );
                },
              ),

              // ── Manufacturing Services tab ──────────────────────────────
              svcListings.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
                data: (listings) {
                  if (listings.isEmpty) {
                    return _EmptyState(
                      icon: Icons.build_outlined,
                      message: 'No services listed yet',
                      hint: 'Tap + to add a service',
                      onAdd: () => context.push('/manufacturing/create'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(_myMfgServicesProvider(listingKey)),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: listings.length,
                      itemBuilder: (_, i) {
                        final s = listings[i];
                        final pricingLabel = s.pricingUnit != null
                            ? s.pricingUnit!.replaceAll('_', ' ')
                            : '';
                        return _SimpleListingCard(
                          title: s.title,
                          subtitle: s.location ?? s.serviceType ?? '',
                          price: '${formatCurrencyForMode(s.price, currency: s.currency, viewerCountry: userCountry, decimals: 2, mode: mode)}'
                              '${pricingLabel.isNotEmpty ? ' / $pricingLabel' : ''}',
                          status: s.status,
                          imageUrl: s.images?.isNotEmpty == true
                              ? s.images!.first
                              : null,
                          placeholderIcon: Icons.build,
                          onView: () =>
                              context.push('/manufacturing/service/${s.id}'),
                          onEdit: () =>
                              context.push('/manufacturing/service/${s.id}/edit'),
                          onChangeStatus: () =>
                              _changeMfgSvcStatus(s, listingKey),
                          onDelete: () =>
                              _deleteMfgService(s, listingKey),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          if (_deleting)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black12,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty state helper ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.hint,
    required this.onAdd,
  });

  final IconData icon;
  final String message;
  final String hint;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(hint, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Listing'),
              onPressed: onAdd,
            ),
          ],
        ),
      );
}

// ─── Property listing card ────────────────────────────────────────────────────

class _PropertyListingCard extends ConsumerWidget {
  const _PropertyListingCard({
    required this.property,
    required this.onView,
    required this.onEdit,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final PropertyModel property;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onChangeStatus;
  final VoidCallback onDelete;

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'sold':
        return Colors.red;
      case 'rented':
        return Colors.blue;
      case 'unavailable':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = property;
    final color = _statusColor(p.status);
    final mode = ref.watch(marketplaceModeProvider);
    final userCountry = ref.watch(userCountryProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: p.imageUrls.isNotEmpty
            ? GestureDetector(
                onTap: () => _SimpleListingCard._openImagePreview(
                    context, p.imageUrls.first, p.title),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: p.imageUrls.first,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[200],
                    ),
                    errorWidget: (_, __, ___) => const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              )
            : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.apartment,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
        title: Text(
          p.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.city != null ? '${p.city}  ·  ${p.address}' : p.address,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    formatCurrencyForMode(
                      p.price,
                      country: p.country,
                      viewerCountry: userCountry,
                      mode: mode,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                    border:
                        Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    p.status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'view') onView();
            if (v == 'edit') onEdit();
            if (v == 'status') onChangeStatus();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                )),
            PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('View'),
                  ],
                )),
            PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Change Status'),
                  ],
                )),
            PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                )),
          ],
        ),
        onTap: onView,
      ),
    );
  }
}

// ─── Generic agri / mfg listing card ─────────────────────────────────────────

class _SimpleListingCard extends StatelessWidget {
  const _SimpleListingCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.status,
    required this.imageUrl,
    required this.placeholderIcon,
    required this.onView,
    required this.onEdit,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final String price;
  final String status;
  final String? imageUrl;
  final IconData placeholderIcon;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onChangeStatus;
  final VoidCallback onDelete;

  Color _statusColor(String s) {
    switch (s) {
      case 'available':
        return Colors.green;
      case 'sold_out':
      case 'discontinued':
        return Colors.red;
      case 'reserved':
      case 'out_of_stock':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: imageUrl != null
            ? GestureDetector(
                onTap: () => _openImagePreview(context, imageUrl!, title),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[200],
                    ),
                    errorWidget: (_, __, ___) => const SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              )
            : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(placeholderIcon,
                    color: Theme.of(context).colorScheme.primary),
              ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(subtitle,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'view') onView();
            if (v == 'edit') onEdit();
            if (v == 'status') onChangeStatus();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                )),
            PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('View'),
                  ],
                )),
            PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Change Status'),
                  ],
                )),
            PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                )),
          ],
        ),
        onTap: onView,
      ),
    );
  }

  static void _openImagePreview(
      BuildContext context, String url, String label) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(label,
                style:
                    const TextStyle(color: Colors.white, fontSize: 15)),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const CircularProgressIndicator(),
                errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
