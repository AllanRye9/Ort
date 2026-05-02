import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
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

final _myAgriListingsProvider =
    FutureProvider.autoDispose.family<List<AgricultureListingModel>, int?>((ref, tenantId) async {
  if (tenantId == null) return const [];
  final data = await ref
      .read(apiServiceProvider)
      .getAgricultureListings(tenantId: tenantId, limit: 200);
  return data.map((j) => AgricultureListingModel.fromJson(j as Map<String, dynamic>)).toList();
});

final _myMfgListingsProvider =
    FutureProvider.autoDispose.family<List<ManufacturingProductModel>, int?>((ref, tenantId) async {
  if (tenantId == null) return const [];
  final data = await ref
      .read(apiServiceProvider)
      .getManufacturingProducts(tenantId: tenantId, limit: 200);
  return data.map((j) => ManufacturingProductModel.fromJson(j as Map<String, dynamic>)).toList();
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
    _tabCtrl = TabController(length: 3, vsync: this);
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

  Future<void> _deleteAgriListing(AgricultureListingModel a, int? tenantId) async {
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
      ref.invalidate(_myAgriListingsProvider(tenantId));
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

  Future<void> _deleteMfgListing(ManufacturingProductModel m, int? tenantId) async {
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
      ref.invalidate(_myMfgListingsProvider(tenantId));
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

    final propertyListings = ref.watch(_myListingsProvider(userId));
    final agriListings = ref.watch(_myAgriListingsProvider(tenantId));
    final mfgListings = ref.watch(_myMfgListingsProvider(tenantId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.apartment_outlined), text: 'Properties'),
            Tab(icon: Icon(Icons.grass_outlined), text: 'Agriculture'),
            Tab(icon: Icon(Icons.precision_manufacturing_outlined), text: 'Mfg'),
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
                  child: Text('Add Manufacturing')),
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
                        ref.invalidate(_myAgriListingsProvider(tenantId)),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: listings.length,
                      itemBuilder: (_, i) {
                        final a = listings[i];
                        return _SimpleListingCard(
                          title: a.title,
                          subtitle: a.location ?? a.category ?? '',
                          price:
                              '\$${a.pricePerUnit.toStringAsFixed(2)} / ${a.unit ?? 'unit'}',
                          status: a.status,
                          imageUrl: a.images?.isNotEmpty == true
                              ? a.images!.first
                              : null,
                          placeholderIcon: Icons.grass,
                          onView: () =>
                              context.push('/agriculture/${a.id}'),
                          onDelete: () =>
                              _deleteAgriListing(a, tenantId),
                        );
                      },
                    ),
                  );
                },
              ),

              // ── Manufacturing tab ───────────────────────────────────────
              mfgListings.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
                data: (listings) {
                  if (listings.isEmpty) {
                    return _EmptyState(
                      icon: Icons.precision_manufacturing_outlined,
                      message: 'No manufacturing listings yet',
                      hint: 'Tap + to add a product',
                      onAdd: () => context.push('/manufacturing/create'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(_myMfgListingsProvider(tenantId)),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: listings.length,
                      itemBuilder: (_, i) {
                        final m = listings[i];
                        return _SimpleListingCard(
                          title: m.title,
                          subtitle: m.location ?? m.category ?? '',
                          price:
                              '\$${m.wholesalePrice.toStringAsFixed(2)}',
                          status: m.status,
                          imageUrl: m.images?.isNotEmpty == true
                              ? m.images!.first
                              : null,
                          placeholderIcon:
                              Icons.precision_manufacturing,
                          onView: () =>
                              context.push('/manufacturing/${m.id}'),
                          onDelete: () =>
                              _deleteMfgListing(m, tenantId),
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

class _PropertyListingCard extends StatelessWidget {
  const _PropertyListingCard({
    required this.property,
    required this.onView,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final PropertyModel property;
  final VoidCallback onView;
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
  Widget build(BuildContext context) {
    final p = property;
    final color = _statusColor(p.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: p.imageUrls.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  p.imageUrls.first,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(Icons.broken_image_outlined),
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
                Text(
                  '\$${p.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
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
            if (v == 'status') onChangeStatus();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'view', child: Text('View / Edit')),
            PopupMenuItem(value: 'status', child: Text('Change Status')),
            PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: Colors.red))),
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
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final String price;
  final String status;
  final String? imageUrl;
  final IconData placeholderIcon;
  final VoidCallback onView;
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
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.broken_image_outlined)),
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
                Text(price,
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
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
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'view', child: Text('View / Edit')),
            PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: onView,
      ),
    );
  }
}
