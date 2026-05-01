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

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  bool _deleting = false;

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

  @override
  Widget build(BuildContext context) {
    final agentId = ref.watch(authProvider).userId;
    if (agentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Listings')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    final listingsAsync = ref.watch(_myListingsProvider(agentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Listing',
            onPressed: () => context.push('/properties/create'),
          ),
        ],
      ),
      body: listingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error loading listings: $e',
                textAlign: TextAlign.center)),
        data: (listings) {
          if (listings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.apartment_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No listings yet',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Tap + to add your first property listing',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Listing'),
                    onPressed: () => context.push('/properties/create'),
                  ),
                ],
              ),
            );
          }
          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: listings.length,
                itemBuilder: (context, index) {
                  final p = listings[index];
                  return _ListingCard(
                    property: p,
                    onEdit: () => context.push('/properties/${p.id}'),
                    onChangeStatus: () => _changeStatus(p),
                    onDelete: () => _deleteListing(p),
                  );
                },
              ),
              if (_deleting)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black12,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.property,
    required this.onEdit,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final PropertyModel property;
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
                    border: Border.all(color: color.withValues(alpha: 0.4)),
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
            if (v == 'view') onEdit();
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
        onTap: onEdit,
      ),
    );
  }
}
