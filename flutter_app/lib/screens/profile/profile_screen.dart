import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';

final _meProvider = FutureProvider.autoDispose<UserModel>((ref) async {
  final data = await ref.read(apiServiceProvider).getMe();
  return UserModel.fromJson(data);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final meAsync = ref.watch(_meProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.15),
              child: meAsync.maybeWhen(
                data: (u) => Text(
                  '${u.firstName[0]}${u.lastName[0]}'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                orElse: () => Icon(
                  Icons.person,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Name
          meAsync.when(
            loading: () => const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                auth.userId != null ? 'User #${auth.userId}' : 'Not signed in',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            data: (u) => Column(
              children: [
                Text(
                  u.fullName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  u.email,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 8),
                _RoleBadge(role: u.role),
              ],
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

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  Color _color() {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'company':
        return Colors.blue;
      case 'organization':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _color().withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color().withValues(alpha: 0.4)),
        ),
        child: Text(
          role.toUpperCase(),
          style: TextStyle(
            color: _color(),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
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

