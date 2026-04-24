import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              // FIX: withOpacity deprecated → withValues(alpha:)
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.15),
              child: Icon(
                Icons.person,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              auth.userId != null
                  ? 'User #${auth.userId}'
                  : 'Not signed in',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          _ProfileTile(
            icon: Icons.apartment,
            label: 'My Listings',
            onTap: () => context.go('/properties'),
          ),
          _ProfileTile(
            icon: Icons.shopping_bag,
            label: 'My Orders',
            onTap: () => context.go('/orders'),
          ),
          _ProfileTile(
            icon: Icons.business,
            label: 'My Organisation',
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.subscriptions,
            label: 'Subscription',
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.request_quote,
            label: 'My RFQs',
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.star_border,
            label: 'My Reviews',
            onTap: () {},
          ),
          const Divider(),
          _ProfileTile(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: () {},
          ),
          const Divider(),
          _ProfileTile(
            icon: Icons.logout,
            label: 'Sign Out',
            iconColor: Colors.red,
            labelColor: Colors.red,
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(label,
            style:
                labelColor != null ? TextStyle(color: labelColor) : null),
        trailing:
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        onTap: onTap,
      );
}
