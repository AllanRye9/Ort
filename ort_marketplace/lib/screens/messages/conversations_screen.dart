import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/friendly_error.dart';
import '../../models/models.dart';

final _conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final userId = ref.read(authProvider).userId;
  if (userId == null) return const [];
  final data = await ref.read(apiServiceProvider).getConversations(userId);
  return data
      .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _propertyImageProvider =
    FutureProvider.autoDispose.family<String?, int>((ref, propertyId) async {
  final urls = await ref.read(apiServiceProvider).getPropertyImageUrls(propertyId);
  if (urls.isEmpty) return null;
  return urls.first;
});

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  Future<void> _showNewConversationDialog(
      BuildContext context, WidgetRef ref) async {
    final subjectCtrl = TextEditingController();
    final recipientCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Conversation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: recipientCtrl,
              decoration: const InputDecoration(
                labelText: 'ID, UID, email, or business name',
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                prefixIcon: Icon(Icons.place_outlined),
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

    final query = recipientCtrl.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a recipient ID or name')),
      );
      return;
    }

    try {
      final auth = ref.read(authProvider);
      int? recipientId = int.tryParse(query);
      if (recipientId == null) {
        final user =
            await ref.read(apiServiceProvider).lookupConversationRecipient(query);
        recipientId = user['id'] as int?;
      }
      if (recipientId == null) {
        throw Exception('Recipient ID could not be determined from lookup result');
      }
      if (recipientId == auth.userId) {
        throw Exception('Cannot start a conversation with yourself');
      }
      final recipient = await ref.read(apiServiceProvider).getUser(recipientId);
      final role = recipient['role'] as String?;
      if (role != 'agent' && role != 'company' && role != 'organization') {
        throw Exception('Recipient must be an agent, company, or organization');
      }
      final data = await ref.read(apiServiceProvider).createConversation({
        'initiator_id': auth.userId,
        'recipient_id': recipientId,
        if (subjectCtrl.text.trim().isNotEmpty) 'subject': subjectCtrl.text.trim(),
        if (locationCtrl.text.trim().isNotEmpty)
          'location': locationCtrl.text.trim(),
      });
      ref.invalidate(_conversationsProvider);
      final conversationId = data['id'] as int;
      if (context.mounted) context.go('/messages/$conversationId');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage())),
        );
      }
    }
  }

  Future<void> _editConversationLocation(
    BuildContext context,
    WidgetRef ref,
    ConversationModel conversation,
  ) async {
    final ctrl = TextEditingController(text: conversation.location ?? '');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Location'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Location',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final actorId = ref.read(authProvider).userId;
    if (actorId == null) return;
    try {
      await ref.read(apiServiceProvider).updateConversationLocation(
            conversationId: conversation.id,
            actorId: actorId,
            location: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
          );
      ref.invalidate(_conversationsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage())),
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
        error: (_, __) => Center(child: Text(friendlyErrorMessage())),
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
                    onPressed: () => _showNewConversationDialog(context, ref),
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
                  leading: _ConversationAvatar(conversation: c),
                  title: Text(
                    c.subject ?? 'Conversation #${c.id}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${c.location?.isNotEmpty == true ? '📍 ${c.location} · ' : ''}'
                    'Started ${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Update location',
                        onPressed: () => _editConversationLocation(context, ref, c),
                        icon: const Icon(Icons.place_outlined, size: 20),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
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

class _ConversationAvatar extends ConsumerWidget {
  const _ConversationAvatar({required this.conversation});
  final ConversationModel conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (conversation.propertyId == null) {
      return CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(Icons.chat_bubble_outline,
            color: Theme.of(context).colorScheme.primary, size: 16),
      );
    }
    final imageAsync = ref.watch(_propertyImageProvider(conversation.propertyId!));
    final imageUrl = imageAsync.valueOrNull;
    if (imageUrl == null) {
      return CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(Icons.image_outlined,
            color: Theme.of(context).colorScheme.primary, size: 16),
      );
    }
    return CircleAvatar(
      backgroundImage: CachedNetworkImageProvider(imageUrl),
    );
  }
}
