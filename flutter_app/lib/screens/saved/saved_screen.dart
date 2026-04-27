import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';

final _savedItemsProvider =
    FutureProvider.autoDispose<List<SavedItemModel>>((ref) async {
  final userId = ref.read(authProvider).userId;
  if (userId == null) return const [];
  final data = await ref.read(apiServiceProvider).getSavedItems(userId);
  return data
      .map((e) => SavedItemModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(_savedItemsProvider);
    final userId = ref.read(authProvider).userId;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Items')),
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No saved items yet.',
                      style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Tap the bookmark icon on any listing to save it.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_savedItemsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final item = items[i];
                return _SavedTile(
                  item: item,
                  onUnsave: () async {
                    if (userId == null) return;
                    try {
                      await ref.read(apiServiceProvider).unsaveItem(
                            userId: userId,
                            itemType: item.itemType,
                            itemId: item.itemId,
                          );
                      ref.invalidate(_savedItemsProvider);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Could not unsave: $e')),
                        );
                      }
                    }
                  },
                  onTap: () {
                    switch (item.itemType) {
                      case 'property':
                        ctx.go('/properties/${item.itemId}');
                      case 'agriculture':
                        ctx.go('/agriculture/${item.itemId}');
                      case 'manufacturing':
                        ctx.go('/manufacturing/${item.itemId}');
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({
    required this.item,
    required this.onUnsave,
    required this.onTap,
  });

  final SavedItemModel item;
  final VoidCallback onUnsave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (item.itemType) {
      'property' => (Icons.apartment_rounded, 'Property', Colors.blue),
      'agriculture' => (Icons.grass_rounded, 'Agriculture', Colors.green),
      'manufacturing' => (
          Icons.precision_manufacturing_rounded,
          'Manufacturing',
          Colors.orange
        ),
      _ => (Icons.bookmark, item.itemType, Colors.grey),
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text('$label #${item.itemId}'),
        subtitle: Text(
          'Saved ${_timeAgo(item.createdAt)}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.bookmark, color: Colors.amber),
          tooltip: 'Remove from saved',
          onPressed: onUnsave,
        ),
        onTap: onTap,
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return 'just now';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
