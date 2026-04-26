import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';

final _conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  // Guard explicitly; the router redirect should prevent this
  // screen from ever being shown without a valid userId.
  final userId = ref.read(authProvider).userId;
  if (userId == null) return const [];

  final data = await ref.read(apiServiceProvider).getConversations(userId);
  return data
      .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  Future<void> _showNewConversationDialog(
      BuildContext context, WidgetRef ref) async {
    final subjectCtrl = TextEditingController();
    final recipientCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Conversation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: recipientCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Recipient User ID',
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'Subject (optional)',
                prefixIcon: Icon(Icons.subject),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final recipientId = int.tryParse(recipientCtrl.text.trim());
    if (recipientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid recipient ID')),
      );
      return;
    }

    try {
      final auth = ref.read(authProvider);
      final data = await ref.read(apiServiceProvider).createConversation({
        'initiator_id': auth.userId,
        'recipient_id': recipientId,
        if (subjectCtrl.text.trim().isNotEmpty) 'subject': subjectCtrl.text.trim(),
      });
      ref.invalidate(_conversationsProvider);
      final conversationId = data['id'] as int;
      if (context.mounted) context.go('/messages/$conversationId');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start conversation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_conversationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewConversationDialog(context, ref),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('New'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'No conversations yet.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        _showNewConversationDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Start a conversation'),
                  ),
                ],
              ),
            );
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
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Text(
                      '#${c.id}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
