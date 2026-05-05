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

      // Redirect away from the loading splash once initialized.
      if (loc == '/') {
        if (!isAuthenticated) return '/login';
        return '/home';
      }

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/home';
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

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  DateTime? _lastBackPress;

  // ── Back/forward history ─────────────────────────────────────────────────
  final List<String> _historyStack = [];
  final List<String> _forwardStack = [];
  String _prevLocation = '';
  bool _didGoBack = false;
  bool _didGoForward = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc != _prevLocation && _prevLocation.isNotEmpty) {
      // A natural forward navigation pushes previous location to history and
      // clears the forward stack; back/forward button presses skip this.
      if (!_didGoBack && !_didGoForward) {
        setState(() {
          _historyStack.add(_prevLocation);
          _forwardStack.clear();
        });
      }
      _didGoBack = false;
      _didGoForward = false;
    }
    _prevLocation = loc;
  }

  void _goBack(BuildContext context) {
    if (_historyStack.isEmpty) return;
    final current = GoRouterState.of(context).matchedLocation;
    final target = _historyStack.removeLast();
    setState(() {
      _didGoBack = true;
      _forwardStack.add(current);
    });
    context.go(target);
  }

  void _goForward(BuildContext context) {
    if (_forwardStack.isEmpty) return;
    final target = _forwardStack.removeLast();
    setState(() => _didGoForward = true);
    context.go(target);
  }

  static const _tabs = [
    ('/home', Icons.home_outlined, Icons.home_rounded, 'Home'),
    ('/properties', Icons.apartment_outlined, Icons.apartment_rounded, 'Properties'),
    ('/agriculture', Icons.grass_outlined, Icons.grass_rounded, 'Agri'),
    ('/manufacturing', Icons.precision_manufacturing_outlined,
        Icons.precision_manufacturing_rounded, 'Mfg'),
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
    // If the router can go back (e.g., we're on a sub-page), go back.
    if (router.canPop()) {
      router.pop();
      return false;
    }
    // On the root/home level: require a second tap within 2 seconds to exit.
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

    // ── Wide layout: NavigationRail on the left ──────────────────────────────
    if (isWide) {
      final isExtended = width >= 900;
      final canGoBack = _historyStack.isNotEmpty;
      final canGoForward = _forwardStack.isNotEmpty;
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
            Expanded(
              child: Column(
                children: [
                  // ── Back / forward toolbar ──────────────────────────────
                  _NavHistoryBar(
                    canGoBack: canGoBack,
                    canGoForward: canGoForward,
                    onBack: () => _goBack(context),
                    onForward: () => _goForward(context),
                    borderSide: _NavHistoryBorderSide.bottom,
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Narrow layout: BottomNavigationBar ───────────────────────────────────
    final canGoBack = _historyStack.isNotEmpty;
    final canGoForward = _forwardStack.isNotEmpty;

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
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Animated back/forward bar (only when history exists) ────
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: (canGoBack || canGoForward)
                  ? _NavHistoryBar(
                      canGoBack: canGoBack,
                      canGoForward: canGoForward,
                      onBack: () => _goBack(context),
                      onForward: () => _goForward(context),
                      borderSide: _NavHistoryBorderSide.top,
                      dense: true,
                    )
                  : const SizedBox.shrink(),
            ),
            NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_tabs[i].$1),
              destinations: _tabs
                  .map(
                    (t) => NavigationDestination(
                      icon: Icon(t.$2),
                      selectedIcon: Icon(t.$3),
                      label: t.$4,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Back / forward history bar ──────────────────────────────────────────────

enum _NavHistoryBorderSide { top, bottom }

class _NavHistoryBar extends StatelessWidget {
  const _NavHistoryBar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    this.borderSide = _NavHistoryBorderSide.bottom,
    this.dense = false,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final _NavHistoryBorderSide borderSide;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = BorderSide(color: theme.dividerColor, width: 0.5);

    return Material(
      color: cs.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: borderSide == _NavHistoryBorderSide.top
              ? Border(top: border)
              : Border(bottom: border),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: dense ? 0 : 2,
        ),
        child: Row(
          children: [
            AnimatedOpacity(
              opacity: canGoBack ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                onPressed: canGoBack ? onBack : null,
                tooltip: 'Back',
                visualDensity: VisualDensity.compact,
              ),
            ),
            AnimatedOpacity(
              opacity: canGoForward ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onPressed: canGoForward ? onForward : null,
                tooltip: 'Forward',
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
