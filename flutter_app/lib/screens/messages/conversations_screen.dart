import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';

final _conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  // FIX: was using `userId ?? 0` which sends invalid requests when not
  // authenticated. Guard explicitly; the router redirect should prevent this
  // screen from ever being shown without a valid userId, but belt-and-suspenders.
  final userId = ref.read(authProvider).userId;
  if (userId == null) return const [];

  final data = await ref.read(apiServiceProvider).getConversations(userId);
  return data
      .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_conversationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.chat),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_conversationsProvider),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final c = items[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text('#${c.id}'),
                  ),
                  title: Text(
                    c.subject ?? 'Conversation #${c.id}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Started ${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ctx.go('/messages/${c.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
