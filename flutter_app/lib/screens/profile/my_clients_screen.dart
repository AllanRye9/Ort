import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';

final _clientsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final agentId = ref.watch(authProvider).userId;
  if (agentId == null) return {'total': 0, 'clients': []};
  return ref.read(apiServiceProvider).getAgentClients(agentId);
});

class MyClientsScreen extends ConsumerWidget {
  const MyClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_clientsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Clients')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final clients = (data['clients'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          final total = data['total'] as int? ?? 0;

          if (clients.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline,
                      size: 64,
                      color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No clients yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Users who save, bid on, or message\nabout your listings will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: cs.primaryContainer.withValues(alpha: 0.35),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      '$total client${total != 1 ? 's' : ''}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: cs.primary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: clients.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (ctx, i) {
                    final c = clients[i];
                    final actions = (c['actions'] as List<dynamic>? ?? [])
                        .cast<String>();
                    final firstName = c['first_name'] as String? ?? '';
                    final lastName = c['last_name'] as String? ?? '';
                    final email = c['email'] as String? ?? '';
                    final phone = c['phone'] as String?;
                    final avatarUrl = c['avatar_url'] as String?;

                    return ListTile(
                      leading: _Avatar(
                          url: avatarUrl,
                          initials:
                              '${firstName.isNotEmpty ? firstName[0] : '?'}'
                              '${lastName.isNotEmpty ? lastName[0] : ''}'),
                      title: Text(
                        '$firstName $lastName'.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (email.isNotEmpty) Text(email),
                          if (phone != null && phone.isNotEmpty)
                            Text(phone,
                                style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                    fontSize: 12)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: actions
                                .map((a) => _ActionChip(action: a))
                                .toList(),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.initials});
  final String? url;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 24,
      backgroundColor: cs.primaryContainer,
      child: url != null && url!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Text(
                  initials.toUpperCase(),
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold),
                ),
              ),
            )
          : Text(
              initials.toUpperCase(),
              style: TextStyle(
                  color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
            ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});
  final String action;

  Color _color(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (action) {
      case 'saved':
        return cs.secondary;
      case 'bid':
        return cs.primary;
      case 'messaged':
        return const Color(0xFF2E7D32);
      default:
        return cs.tertiary;
    }
  }

  IconData _icon() {
    switch (action) {
      case 'saved':
        return Icons.bookmark_outlined;
      case 'bid':
        return Icons.gavel_outlined;
      case 'messaged':
        return Icons.chat_bubble_outline;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            action,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
