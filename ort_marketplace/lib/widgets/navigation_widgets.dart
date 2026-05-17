import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Standard app bar used across all screens with consistent back button, title, and actions.
/// Supports breadcrumb navigation and integrates with GoRouter for back navigation.
class OrtAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OrtAppBar({
    super.key,
    required this.title,
    this.breadcrumbs,
    this.actions,
    this.backgroundColor,
    this.leading,
    this.centerTitle = false,
    this.elevation = 4,
    this.showBackButton = true,
    this.onBackPressed,
  });

  /// Main title text for the app bar
  final String title;

  /// Optional breadcrumb navigation items: [(label, onTap), ...]
  final List<(String label, VoidCallback onTap)>? breadcrumbs;

  /// Action buttons to display on the right
  final List<Widget>? actions;

  /// Background color (defaults to theme primary)
  final Color? backgroundColor;

  /// Custom leading widget (overrides default back button if provided)
  final Widget? leading;

  /// Whether to center the title
  final bool centerTitle;

  /// App bar elevation
  final double elevation;

  /// Whether to show a back button
  final bool showBackButton;

  /// Called when back button is pressed (overrides default GoRouter pop)
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: breadcrumbs != null && breadcrumbs!.isNotEmpty
          ? _BreadcrumbNavigation(
              title: title,
              breadcrumbs: breadcrumbs!,
            )
          : Text(title),
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: backgroundColor,
      leading: leading ??
          (showBackButton
              ? BackButton(
                  onPressed: onBackPressed ?? () => context.pop(),
                )
              : null),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Displays breadcrumb navigation with tappable items
class _BreadcrumbNavigation extends StatelessWidget {
  const _BreadcrumbNavigation({
    required this.title,
    required this.breadcrumbs,
  });

  final String title;
  final List<(String label, VoidCallback onTap)> breadcrumbs;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...List.generate(
            breadcrumbs.length,
            (i) {
              final (label, onTap) = breadcrumbs[i];
              return Row(
                children: [
                  InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      ' / ',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ),
                ],
              );
            },
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Quick navigation drawer providing access to all main sections
class QuickNavigationDrawer extends StatelessWidget {
  const QuickNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Ort Marketplace',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Navigate your way',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          _NavigationDrawerSection(
            title: 'Browse',
            items: [
              (Icons.home_outlined, 'Home', '/home'),
              (Icons.apartment_outlined, 'Properties', '/properties'),
              (Icons.grass_outlined, 'Agriculture', '/agriculture'),
              (Icons.precision_manufacturing_outlined, 'Manufacturing', '/manufacturing'),
            ],
          ),
          const Divider(),
          _NavigationDrawerSection(
            title: 'My Activity',
            items: [
              (Icons.chat_bubble_outline, 'Messages', '/messages'),
              (Icons.notifications_outlined, 'Notifications', '/notifications'),
              (Icons.list_alt_outlined, 'My Listings', '/my-listings'),
              (Icons.shopping_cart_outlined, 'Orders', '/orders'),
            ],
          ),
          const Divider(),
          _NavigationDrawerSection(
            title: 'Manage',
            items: [
              (Icons.request_quote_outlined, 'RFQs', '/my-rfqs'),
              (Icons.rate_review_outlined, 'Reviews', '/my-reviews'),
              (Icons.savings_outlined, 'Wallet', '/wallet'),
              (Icons.analytics_outlined, 'Analytics', '/analytics'),
            ],
          ),
          const Divider(),
          _NavigationDrawerSection(
            title: 'More',
            items: [
              (Icons.person_outlined, 'Profile', '/profile'),
              (Icons.track_changes_outlined, 'Tracking', '/tracking'),
              (Icons.stars_outlined, 'AI Assistant', '/ai-assistant'),
              (Icons.settings_outlined, 'Settings', '/settings'),
            ],
          ),
        ],
      ),
    );
  }
}

/// A section within the navigation drawer with multiple items
class _NavigationDrawerSection extends StatelessWidget {
  const _NavigationDrawerSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<(IconData icon, String label, String route)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items.map(
          (item) {
            final (icon, label, route) = item;
            return ListTile(
              leading: Icon(icon, size: 20),
              title: Text(label, style: const TextStyle(fontSize: 13)),
              onTap: () {
                context.go(route);
                Navigator.pop(context); // Close drawer after navigation
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ],
    );
  }
}

/// Floating action button providing quick access to create new listings
class QuickActionFab extends StatelessWidget {
  const QuickActionFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showQuickCreateMenu(context),
      icon: const Icon(Icons.add),
      label: const Text('Create'),
    );
  }

  void _showQuickCreateMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Create New Listing',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.apartment_outlined),
              title: const Text('Property'),
              onTap: () {
                Navigator.pop(context);
                context.go('/properties/create');
              },
            ),
            ListTile(
              leading: const Icon(Icons.grass_outlined),
              title: const Text('Agriculture'),
              onTap: () {
                Navigator.pop(context);
                context.go('/agriculture/create');
              },
            ),
            ListTile(
              leading: const Icon(Icons.precision_manufacturing_outlined),
              title: const Text('Manufacturing'),
              onTap: () {
                Navigator.pop(context);
                context.go('/manufacturing/create');
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for navigating between sections with quick access
class NavigationBottomSheet extends StatelessWidget {
  const NavigationBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Quick Navigate',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _NavigationChip(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/home');
                },
              ),
              _NavigationChip(
                icon: Icons.apartment_outlined,
                label: 'Properties',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/properties');
                },
              ),
              _NavigationChip(
                icon: Icons.grass_outlined,
                label: 'Agriculture',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/agriculture');
                },
              ),
              _NavigationChip(
                icon: Icons.precision_manufacturing_outlined,
                label: 'Manufacturing',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/manufacturing');
                },
              ),
              _NavigationChip(
                icon: Icons.chat_bubble_outline,
                label: 'Messages',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/messages');
                },
              ),
              _NavigationChip(
                icon: Icons.list_alt_outlined,
                label: 'My Listings',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/my-listings');
                },
              ),
              _NavigationChip(
                icon: Icons.shopping_cart_outlined,
                label: 'Orders',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/orders');
                },
              ),
              _NavigationChip(
                icon: Icons.person_outlined,
                label: 'Profile',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/profile');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Individual navigation chip for quick access
class _NavigationChip extends StatelessWidget {
  const _NavigationChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
