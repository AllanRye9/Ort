import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/properties/properties_screen.dart';
import '../screens/properties/property_detail_screen.dart';
import '../screens/agriculture/agriculture_screen.dart';
import '../screens/agriculture/agriculture_detail_screen.dart';
import '../screens/manufacturing/manufacturing_screen.dart';
import '../screens/manufacturing/manufacturing_detail_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/messages/conversations_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../screens/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isAuthenticated ? '/home' : '/login',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/properties',
            builder: (_, __) => const PropertiesScreen(),
            routes: [
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
        ],
      ),
    ],
  );
});

/// Bottom-navigation shell wrapper.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    ('/home', Icons.home_outlined, Icons.home, 'Home'),
    ('/properties', Icons.apartment_outlined, Icons.apartment, 'Properties'),
    ('/agriculture', Icons.grass_outlined, Icons.grass, 'Agri'),
    ('/manufacturing', Icons.factory_outlined, Icons.factory, 'Mfg'),
    ('/orders', Icons.shopping_bag_outlined, Icons.shopping_bag, 'Orders'),
    ('/messages', Icons.chat_outlined, Icons.chat, 'Messages'),
    ('/profile', Icons.person_outlined, Icons.person, 'Profile'),
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
