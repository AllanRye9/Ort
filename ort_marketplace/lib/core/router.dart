import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/properties/properties_screen.dart';
import '../screens/properties/property_detail_screen.dart';
import '../screens/properties/property_create_screen.dart';
import '../screens/agriculture/agriculture_screen.dart';
import '../screens/agriculture/agriculture_detail_screen.dart';
import '../screens/agriculture/agriculture_create_screen.dart';
import '../screens/manufacturing/manufacturing_screen.dart';
import '../screens/manufacturing/manufacturing_detail_screen.dart';
import '../screens/manufacturing/manufacturing_create_screen.dart';
import '../screens/manufacturing/manufacturing_service_detail_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/messages/conversations_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/public_profile_screen.dart';
import '../screens/profile/my_listings_screen.dart';
import '../screens/profile/my_clients_screen.dart';
import '../screens/profile/analytics_screen.dart';
import '../screens/agriculture/agriculture_edit_screen.dart';
import '../screens/manufacturing/manufacturing_edit_screen.dart';
import '../screens/properties/property_edit_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/saved/saved_screen.dart';
import '../screens/search/distance_calculator_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../screens/tracking/product_tracking_screen.dart';
import '../screens/ai/ai_assistant_screen.dart';
import '../screens/rfq/my_rfqs_screen.dart';
import '../screens/reviews/my_reviews_screen.dart';

// ─── Auth-change listenable ──────────────────────────────────────────────────
//
// We use a ChangeNotifier driven by Riverpod's ref.listen so that the GoRouter
// instance is created ONCE and never replaced (no navigation-stack wipe on
// sign-in/out). GoRouter's refreshListenable calls its redirect callback
// whenever the notifier fires.

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    _sub = ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.isAuthenticated != next.isAuthenticated ||
          prev?.isInitialized != next.isInitialized) {
        notifyListeners();
      }
    });
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final _authChangeNotifierProvider =
    ChangeNotifierProvider<_AuthChangeNotifier>(
  (ref) => _AuthChangeNotifier(ref),
);

// ─── Router provider ─────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_authChangeNotifierProvider);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No route for "${state.uri}"'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    ),
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // Wait for the initial token load to finish before redirecting.
      // This prevents a flash of the login screen on Flutter Web where
      // the IndexedDB read is async and slower than on native platforms.
      if (!authState.isInitialized) return null;

      final isAuthenticated = authState.isAuthenticated;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';
      final role = authState.role ?? 'user';

      // Redirect away from the loading splash once initialized.
      if (loc == '/') {
        if (!isAuthenticated) return '/login';
        return '/home';
      }

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/home';
      if (isAuthenticated && role == 'user' && loc.startsWith('/orders')) {
        return '/my-rfqs';
      }
      if (isAuthenticated &&
          role != 'user' &&
          loc.startsWith('/my-rfqs')) {
        return '/profile';
      }
      return null;
    },
    routes: [
      // Loading / splash route shown while initial auth state is determined.
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      // Full-screen routes (no bottom nav)
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(
        path: '/distance-calculator',
        builder: (_, __) => const DistanceCalculatorScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/saved', builder: (_, __) => const SavedScreen()),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
      GoRoute(path: '/my-rfqs', builder: (_, __) => const MyRfqsScreen()),
      GoRoute(path: '/my-reviews', builder: (_, __) => const MyReviewsScreen()),
      GoRoute(path: '/my-listings', builder: (_, __) => const MyListingsScreen()),
      GoRoute(path: '/my-clients', builder: (_, __) => const MyClientsScreen()),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(
            path: '/properties',
            builder: (_, __) => const PropertiesScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (_, __) => const PropertyCreateScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => PropertyDetailScreen(
                  id: int.parse(state.pathParameters['id']!),
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => PropertyEditScreen(
                      id: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/agriculture',
            builder: (_, __) => const AgricultureScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (_, __) => const AgricultureCreateScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => AgricultureDetailScreen(
                  id: int.parse(state.pathParameters['id']!),
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => AgricultureEditScreen(
                      id: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/manufacturing',
            builder: (_, __) => const ManufacturingScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (_, __) => const ManufacturingCreateScreen(),
              ),
              GoRoute(
                path: 'service/:id',
                builder: (_, state) => ManufacturingServiceDetailScreen(
                  id: int.parse(state.pathParameters['id']!),
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => ManufacturingDetailScreen(
                  id: int.parse(state.pathParameters['id']!),
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => ManufacturingEditScreen(
                      id: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrdersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => OrderDetailScreen(
                  id: int.parse(state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/messages',
            builder: (_, __) => const ConversationsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => ChatScreen(
                  conversationId: int.parse(state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/user/:id',
            builder: (_, state) => PublicProfileScreen(
              userId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/tracking/:orderId',
            builder: (_, state) => ProductTrackingScreen(
              orderId: int.parse(state.pathParameters['orderId']!),
            ),
          ),
          GoRoute(
            path: '/ai-assistant',
            builder: (_, __) => const AiAssistantScreen(),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

// ─── Bottom-navigation shell ──────────────────────────────────────────────────

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastBackPress;

  static const _tabs = [
    ('/home', Icons.home_outlined, Icons.home_rounded, 'Home'),
    ('/properties', Icons.apartment_outlined, Icons.apartment_rounded, 'Properties'),
    ('/agriculture', Icons.grass_outlined, Icons.grass_rounded, 'Agriculture'),
    ('/manufacturing', Icons.precision_manufacturing_outlined,
        Icons.precision_manufacturing_rounded, 'Manufacturing'),
    ('/messages', Icons.chat_bubble_outline, Icons.chat_bubble_rounded, 'Messages'),
    ('/profile', Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  Future<bool> _onWillPop(BuildContext context) async {
    final router = GoRouter.of(context);
    // If the router can go back (e.g., we're on a sub-page pushed via
    // context.push), let the router handle it.
    if (router.canPop()) {
      router.pop();
      return false;
    }
    // On the root/home level: require a second tap within
    // 2 seconds to exit.
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 600;
    final role = ref.watch(authProvider).role ?? 'user';

    // ── Wide layout: NavigationRail on the left ──────────────────────────────
    if (isWide) {
      final isExtended = width >= 900;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_tabs[i].$1),
              labelType: isExtended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              extended: isExtended,
              leading: isExtended
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Ort',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
              destinations: _tabs
                  .map(
                    (t) => NavigationRailDestination(
                      icon: Icon(t.$2),
                      selectedIcon: Icon(t.$3),
                      label: Text(t.$4),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // ── Narrow layout: BottomNavigationBar ───────────────────────────────────
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onWillPop(context);
        if (shouldExit && context.mounted) {
          // SystemNavigator.pop() is Android-only; on web there is no such
          // concept (and it would throw), so skip it.
          if (!kIsWeb) await SystemNavigator.pop();
        }
      },
      child: Scaffold(
         body: widget.child,
         floatingActionButton: FloatingActionButton.small(
           heroTag: 'global-nav-fab',
           onPressed: () => _showMobileNavigationSheet(context, role),
           child: const Icon(Icons.menu),
         ),
         bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 74,
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (_) => const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(_tabs[i].$1),
            destinations: _tabs
                .map(
                  (t) => NavigationDestination(
                    icon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(t.$2),
                    ),
                    selectedIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(t.$3),
                    ),
                    label: t.$4,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showMobileNavigationSheet(BuildContext context, String role) {
    final links = <(String route, IconData icon, String label)>[
      ('/home', Icons.home_outlined, 'Home'),
      ('/properties', Icons.apartment_outlined, 'Properties'),
      ('/agriculture', Icons.grass_outlined, 'Agriculture'),
      ('/manufacturing', Icons.precision_manufacturing_outlined, 'Manufacturing'),
      ('/messages', Icons.chat_bubble_outline, 'Messages'),
      ('/profile', Icons.person_outline_rounded, 'Profile'),
      ('/wallet', Icons.account_balance_wallet_outlined, 'My Wallet'),
      ('/saved', Icons.bookmark_border, 'Saved Items'),
      ('/settings', Icons.settings_outlined, 'Settings'),
      if (role == 'user') ('/my-rfqs', Icons.request_quote_outlined, 'My RFQs'),
      if (role != 'user') ('/orders', Icons.shopping_bag_outlined, 'My Orders'),
      ('/my-reviews', Icons.star_border, 'My Reviews'),
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: links.length,
          itemBuilder: (_, i) {
            final link = links[i];
            return ListTile(
              leading: Icon(link.$2),
              title: Text(link.$3),
              onTap: () {
                Navigator.of(ctx).pop();
                context.go(link.$1);
              },
            );
          },
        ),
      ),
    );
  }
}
