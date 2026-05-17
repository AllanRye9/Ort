import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

/// Service to manage navigation patterns across the Ort marketplace app.
/// Centralizes navigation logic, back button behavior, and route management.
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();

  NavigationService._internal();

  factory NavigationService() => _instance;

  /// Navigation stack for tracking navigation history
  final List<String> _navigationStack = [];

  /// Breadcrumb items for current screen
  List<(String label, VoidCallback onTap)>? _currentBreadcrumbs;

  /// Get current breadcrumbs
  List<(String label, VoidCallback onTap)>? get breadcrumbs => _currentBreadcrumbs;

  /// Set breadcrumbs for current screen
  void setBreadcrumbs(List<(String label, VoidCallback onTap)>? items) {
    _currentBreadcrumbs = items;
  }

  /// Clear breadcrumbs
  void clearBreadcrumbs() {
    _currentBreadcrumbs = null;
  }

  /// Push a new route and record in navigation stack
  void pushRoute(BuildContext context, String route) {
    _navigationStack.add(route);
    context.push(route);
  }

  /// Go to a route (replace navigation stack)
  void goToRoute(BuildContext context, String route) {
    _navigationStack.clear();
    _navigationStack.add(route);
    context.go(route);
  }

  /// Go back to previous route
  void goBack(BuildContext context) {
    if (_navigationStack.isNotEmpty) {
      _navigationStack.removeLast();
    }
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Get current navigation stack
  List<String> getNavigationStack() => List.from(_navigationStack);

  /// Clear navigation stack
  void clearNavigationStack() {
    _navigationStack.clear();
  }

  /// Create breadcrumbs from a route path
  /// Example: /agriculture/123 -> [('Agriculture', callback), ('Detail', callback)]
  static List<(String label, VoidCallback onTap)>? createBreadcrumbs(
    BuildContext context,
    String currentPath, {
    required List<(String path, String label)> breadcrumbItems,
  }) {
    if (breadcrumbItems.isEmpty) return null;

    final items = <(String label, VoidCallback onTap)>[];
    for (final (path, label) in breadcrumbItems) {
      items.add((
        label,
        () => context.go(path),
      ));
    }
    return items;
  }
}

/// Extension on BuildContext for convenient navigation
extension NavigationContextExtension on BuildContext {
  /// Navigate to home
  void goHome() => go('/home');

  /// Navigate to properties
  void goProperties() => go('/properties');

  /// Navigate to agriculture
  void goAgriculture() => go('/agriculture');

  /// Navigate to manufacturing
  void goManufacturing() => go('/manufacturing');

  /// Navigate to messages
  void goMessages() => go('/messages');

  /// Navigate to profile
  void goProfile() => go('/profile');

  /// Navigate to orders
  void goOrders() => go('/orders');

  /// Navigate to my listings
  void goMyListings() => go('/my-listings');

  /// Navigate to saved items
  void goSaved() => go('/saved');

  /// Navigate to wallet
  void goWallet() => go('/wallet');

  /// Navigate to notifications
  void goNotifications() => go('/notifications');

  /// Navigate to settings
  void goSettings() => go('/settings');

  /// Navigate to AI assistant
  void goAiAssistant() => go('/ai-assistant');

  /// Create navigation breadcrumbs for properties section
  static List<(String label, VoidCallback onTap)>? propertiesBreadcrumbs(
    BuildContext context, {
    required String currentPath,
    int? propertyId,
  }) {
    final items = <(String label, VoidCallback onTap)>[];
    items.add(('Properties', () => context.goProperties()));

    if (propertyId != null && currentPath.contains('/properties/$propertyId')) {
      items.add(('Detail', () {})); // Current page, non-clickable would be better but this works
    }

    return items;
  }

  /// Create navigation breadcrumbs for agriculture section
  static List<(String label, VoidCallback onTap)>? agricultureBreadcrumbs(
    BuildContext context, {
    required String currentPath,
    int? listingId,
  }) {
    final items = <(String label, VoidCallback onTap)>[];
    items.add(('Agriculture', () => context.goAgriculture()));

    if (listingId != null && currentPath.contains('/agriculture/$listingId')) {
      items.add(('Detail', () {}));
    }

    return items;
  }

  /// Create navigation breadcrumbs for manufacturing section
  static List<(String label, VoidCallback onTap)>? manufacturingBreadcrumbs(
    BuildContext context, {
    required String currentPath,
    int? productId,
  }) {
    final items = <(String label, VoidCallback onTap)>[];
    items.add(('Manufacturing', () => context.goManufacturing()));

    if (productId != null && currentPath.contains('/manufacturing/$productId')) {
      items.add(('Detail', () {}));
    }

    return items;
  }

  /// Create navigation breadcrumbs for orders section
  static List<(String label, VoidCallback onTap)>? ordersBreadcrumbs(
    BuildContext context, {
    required String currentPath,
    int? orderId,
  }) {
    final items = <(String label, VoidCallback onTap)>[];
    items.add(('Orders', () => context.goOrders()));

    if (orderId != null && currentPath.contains('/orders/$orderId')) {
      items.add(('Detail', () {}));
    }

    return items;
  }

  /// Create navigation breadcrumbs for messages section
  static List<(String label, VoidCallback onTap)>? messagesBreadcrumbs(
    BuildContext context, {
    required String currentPath,
    int? conversationId,
  }) {
    final items = <(String label, VoidCallback onTap)>[];
    items.add(('Messages', () => context.goMessages()));

    if (conversationId != null &&
        currentPath.contains('/messages/$conversationId')) {
      items.add(('Chat', () {}));
    }

    return items;
  }
}

/// Navigation helper for managing common screen transitions
class NavigationHelper {
  /// Navigate to detail screen with breadcrumbs
  static void goToDetail(
    BuildContext context, {
    required String section, // 'properties', 'agriculture', 'manufacturing', 'orders'
    required int id,
    required String detailPath,
  }) {
    final breadcrumbs = _getBreadcrumbsForSection(context, section, id);
    NavigationService().setBreadcrumbs(breadcrumbs);
    context.push(detailPath);
  }

  /// Navigate to edit screen with breadcrumbs
  static void goToEdit(
    BuildContext context, {
    required String section,
    required int id,
    required String editPath,
  }) {
    final breadcrumbs = _getBreadcrumbsForSection(context, section, id);
    breadcrumbs?.add(('Edit', () {}));
    NavigationService().setBreadcrumbs(breadcrumbs);
    context.push(editPath);
  }

  /// Navigate to create screen with breadcrumbs
  static void goToCreate(
    BuildContext context, {
    required String section, // 'properties', 'agriculture', 'manufacturing'
    required String createPath,
  }) {
    final breadcrumbs = _getBreadcrumbsForSection(context, section, null);
    breadcrumbs?.add(('Create', () {}));
    NavigationService().setBreadcrumbs(breadcrumbs);
    context.push(createPath);
  }

  /// Get breadcrumbs for a section
  static List<(String label, VoidCallback onTap)>? _getBreadcrumbsForSection(
    BuildContext context,
    String section,
    int? itemId,
  ) {
    switch (section) {
      case 'properties':
        return NavigationContextExtension.propertiesBreadcrumbs(
          context,
          currentPath: '',
          propertyId: itemId,
        );
      case 'agriculture':
        return NavigationContextExtension.agricultureBreadcrumbs(
          context,
          currentPath: '',
          listingId: itemId,
        );
      case 'manufacturing':
        return NavigationContextExtension.manufacturingBreadcrumbs(
          context,
          currentPath: '',
          productId: itemId,
        );
      case 'orders':
        return NavigationContextExtension.ordersBreadcrumbs(
          context,
          currentPath: '',
          orderId: itemId,
        );
      case 'messages':
        return NavigationContextExtension.messagesBreadcrumbs(
          context,
          currentPath: '',
          conversationId: itemId,
        );
      default:
        return null;
    }
  }

  /// Show a navigation menu for quick access
  static void showNavigationMenu(BuildContext context) {
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
                'Navigate To',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            _buildMenuButton(
              context,
              Icons.home_outlined,
              'Home',
              () => context.goHome(),
            ),
            _buildMenuButton(
              context,
              Icons.apartment_outlined,
              'Properties',
              () => context.goProperties(),
            ),
            _buildMenuButton(
              context,
              Icons.grass_outlined,
              'Agriculture',
              () => context.goAgriculture(),
            ),
            _buildMenuButton(
              context,
              Icons.precision_manufacturing_outlined,
              'Manufacturing',
              () => context.goManufacturing(),
            ),
            _buildMenuButton(
              context,
              Icons.chat_bubble_outline,
              'Messages',
              () => context.goMessages(),
            ),
            _buildMenuButton(
              context,
              Icons.list_alt_outlined,
              'My Listings',
              () => context.goMyListings(),
            ),
            _buildMenuButton(
              context,
              Icons.shopping_cart_outlined,
              'Orders',
              () => context.goOrders(),
            ),
            _buildMenuButton(
              context,
              Icons.person_outlined,
              'Profile',
              () => context.goProfile(),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildMenuButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }
}
