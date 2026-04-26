import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';

final _adminStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getAdminStats();
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_adminStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
          tooltip: 'Back to App',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_adminStatsProvider),
          ),
        ],
      ),
      drawer: const _AdminDrawer(),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => _DashboardContent(stats: stats),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1B5E20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Admin Panel',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_rounded),
            title: const Text('Dashboard'),
            onTap: () { Navigator.pop(context); context.go('/admin'); },
          ),
          ListTile(
            leading: const Icon(Icons.people_rounded),
            title: const Text('User Management'),
            onTap: () { Navigator.pop(context); context.go('/admin/users'); },
          ),
          ListTile(
            leading: const Icon(Icons.article_rounded),
            title: const Text('Content Moderation'),
            onTap: () { Navigator.pop(context); context.go('/admin/content'); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Media Library'),
            onTap: () { Navigator.pop(context); context.go('/admin/media'); },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded),
            title: const Text('Reports & Analytics'),
            onTap: () { Navigator.pop(context); context.go('/admin/reports'); },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('Support Tickets'),
            onTap: () { Navigator.pop(context); context.go('/admin/tickets'); },
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Admin Logs'),
            onTap: () { Navigator.pop(context); context.go('/admin/logs'); },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_rounded),
            title: const Text('Broadcast Notifications'),
            onTap: () { Navigator.pop(context); context.go('/admin/notifications'); },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Back to App'),
            onTap: () { Navigator.pop(context); context.go('/home'); },
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        icon: Icons.people_rounded,
        label: 'Total Users',
        value: '${stats['total_users'] ?? 0}',
        color: const Color(0xFF1B5E20),
      ),
      _StatCard(
        icon: Icons.person_add_rounded,
        label: 'New Users (30d)',
        value: '${stats['new_users_last_30_days'] ?? 0}',
        color: const Color(0xFF2E7D32),
      ),
      _StatCard(
        icon: Icons.apartment_rounded,
        label: 'Properties',
        value: '${stats['total_properties'] ?? 0}',
        color: const Color(0xFF1565C0),
      ),
      _StatCard(
        icon: Icons.shopping_cart_rounded,
        label: 'Total Orders',
        value: '${stats['total_orders'] ?? 0}',
        color: const Color(0xFFE65100),
      ),
      _StatCard(
        icon: Icons.pending_actions_rounded,
        label: 'Pending Orders',
        value: '${stats['pending_orders'] ?? 0}',
        color: const Color(0xFFF57C00),
      ),
      _StatCard(
        icon: Icons.support_agent_rounded,
        label: 'Open Tickets',
        value: '${stats['open_support_tickets'] ?? 0}',
        color: const Color(0xFFC62828),
      ),
      _StatCard(
        icon: Icons.chat_bubble_rounded,
        label: 'Messages',
        value: '${stats['total_messages'] ?? 0}',
        color: const Color(0xFF6A1B9A),
      ),
      _StatCard(
        icon: Icons.business_rounded,
        label: 'Tenants',
        value: '${stats['total_tenants'] ?? 0}',
        color: const Color(0xFF00695C),
      ),
    ];

    final usersByRole = stats['users_by_role'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: cards,
          ),
          const SizedBox(height: 24),
          Text('Users by Role', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: usersByRole.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B5E20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${e.value}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
              ],
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
