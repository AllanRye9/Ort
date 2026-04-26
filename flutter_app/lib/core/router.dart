import 'package:flutter/material.dart';
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
import '../screens/orders/orders_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/messages/conversations_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/gamification/challenges_screen.dart';
import '../screens/gamification/leaderboard_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/privacy/privacy_screen.dart';

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
        return isAuthenticated ? '/home' : '/login';
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
      GoRoute(
        path: '/onboarding',
        builder: (_, state) => OnboardingScreen(
          role: state.uri.queryParameters['role'] ?? 'user',
        ),
      ),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      // Full-screen routes (no bottom nav)
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
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
                path: ':id',
                builder: (_, state) => ManufacturingDetailScreen(
                  id: int.parse(state.pathParameters['id']!),
                ),
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
          GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/challenges', builder: (_, __) => const ChallengesScreen()),
          GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

// ─── Bottom-navigation shell ──────────────────────────────────────────────────

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    ('/home', Icons.home_outlined, Icons.home_rounded, 'Home'),
    ('/properties', Icons.apartment_outlined, Icons.apartment_rounded, 'Properties'),
    ('/agriculture', Icons.grass_outlined, Icons.grass_rounded, 'Agri'),
    ('/manufacturing', Icons.precision_manufacturing_outlined,
        Icons.precision_manufacturing_rounded, 'Mfg'),
    ('/messages', Icons.chat_bubble_outline, Icons.chat_bubble_rounded, 'Messages'),
    ('/feed', Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded, 'Feed'),
    ('/dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
    ('/profile', Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
