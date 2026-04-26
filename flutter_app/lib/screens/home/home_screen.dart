import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

final _propertiesProvider = FutureProvider.autoDispose<List<PropertyModel>>(
  (ref) async {
    final data = await ref.read(apiServiceProvider).getProperties(limit: 20);
    return data
        .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final _agricultureProvider =
    FutureProvider.autoDispose<List<AgricultureListingModel>>(
  (ref) async {
    final data =
        await ref.read(apiServiceProvider).getAgricultureListings(limit: 6);
    return data
        .map((e) =>
            AgricultureListingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final _mfgProvider =
    FutureProvider.autoDispose<List<ManufacturingProductModel>>(
  (ref) async {
    final data =
        await ref.read(apiServiceProvider).getManufacturingProducts(limit: 6);
    return data
        .map((e) =>
            ManufacturingProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

// ─── Role-specific quick actions ──────────────────────────────────────────────

const _agentQuickActions = [
  _QuickAction(Icons.add_business_outlined, 'New Listing', '/properties/create', Color(0xFF1B5E20)),
  _QuickAction(Icons.people_outline, 'My Clients', '/properties', Color(0xFF1565C0)),
  _QuickAction(Icons.bar_chart_outlined, 'Analytics', '/orders', Color(0xFF6A1B9A)),
  _QuickAction(Icons.star_border_outlined, 'Reviews', '/profile', Color(0xFFE65100)),
];

const _companyQuickActions = [
  _QuickAction(Icons.storefront_outlined, 'My Products', '/manufacturing', Color(0xFFE65100)),
  _QuickAction(Icons.request_quote_outlined, 'RFQs', '/orders', Color(0xFF1565C0)),
  _QuickAction(Icons.people_outline, 'Customers', '/messages', Color(0xFF2E7D32)),
  _QuickAction(Icons.analytics_outlined, 'Dashboard', '/orders', Color(0xFF6A1B9A)),
];

const _organizationQuickActions = [
  _QuickAction(Icons.grass_outlined, 'My Listings', '/agriculture', Color(0xFF2E7D32)),
  _QuickAction(Icons.handshake_outlined, 'Partnerships', '/messages', Color(0xFF1565C0)),
  _QuickAction(Icons.campaign_outlined, 'Campaigns', '/notifications', Color(0xFFE65100)),
  _QuickAction(Icons.analytics_outlined, 'Reports', '/orders', Color(0xFF6A1B9A)),
];

const _userQuickActions = [
  _QuickAction(Icons.apartment_outlined, 'Properties', '/properties', Color(0xFF1B5E20)),
  _QuickAction(Icons.grass_outlined, 'Agriculture', '/agriculture', Color(0xFF2E7D32)),
  _QuickAction(Icons.precision_manufacturing_outlined, 'Products', '/manufacturing', Color(0xFFE65100)),
  _QuickAction(Icons.shopping_bag_outlined, 'My Orders', '/orders', Color(0xFF1565C0)),
];

class _QuickAction {
  const _QuickAction(this.icon, this.label, this.route, this.color);
  final IconData icon;
  final String label;
  final String route;
  final Color color;
}

// ─── Home screen ─────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(_propertiesProvider);
    final agricultureAsync = ref.watch(_agricultureProvider);
    final mfgAsync = ref.watch(_mfgProvider);
    final auth = ref.watch(authProvider);
    final role = auth.role ?? 'user';

    final quickActions = switch (role) {
      'agent' => _agentQuickActions,
      'company' => _companyQuickActions,
      'organization' => _organizationQuickActions,
      _ => _userQuickActions,
    };

    final roleLabel = switch (role) {
      'agent' => 'Agent Dashboard',
      'company' => 'Company Dashboard',
      'organization' => 'Organisation Dashboard',
      _ => 'Find properties,\nagriculture & goods',
    };

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_propertiesProvider);
          ref.invalidate(_agricultureProvider);
          ref.invalidate(_mfgProvider);
        },
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
          slivers: [
            // ── Hero app bar ────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 160,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _HeroBanner(
                  greeting: auth.userId != null ? 'Welcome back!' : 'Welcome!',
                  subtitle: roleLabel,
                  onNotifications: () => context.go('/notifications'),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () => context.go('/notifications'),
                ),
              ],
              title: const Text('Ort Marketplace',
                  style: TextStyle(color: Colors.white, fontSize: 17)),
            ),

            // ── Search bar ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _SearchBar(onTap: () => context.go('/search')),
              ),
            ),

            // ── Role-specific quick actions ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role == 'user' ? 'Explore' : 'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _QuickActionsGrid(actions: quickActions),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Featured Properties ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(
                  title: 'Properties',
                  onSeeAll: () => context.go('/properties'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: propertiesAsync.when(
                  loading: () => const _HorizontalShimmer(),
                  error: (e, _) => _ErrorTile(message: e.toString()),
                  data: (items) => _PropertyRow(items: items),
                ),
              ),
            ),

            // ── Agriculture ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(
                  title: 'Agriculture',
                  onSeeAll: () => context.go('/agriculture'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: agricultureAsync.when(
                  loading: () => const _HorizontalShimmer(),
                  error: (e, _) => _ErrorTile(message: e.toString()),
                  data: (items) => _AgriRow(items: items),
                ),
              ),
            ),

            // ── Manufacturing ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(
                  title: 'Manufacturing',
                  onSeeAll: () => context.go('/manufacturing'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: mfgAsync.when(
                  loading: () => const _HorizontalShimmer(),
                  error: (e, _) => _ErrorTile(message: e.toString()),
                  data: (items) => _MfgRow(items: items),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

// ─── Hero banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.greeting,
    required this.subtitle,
    required this.onNotifications,
  });
  final String greeting;
  final String subtitle;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, Color(0xFF388E3C)],
          ),
        ),
        padding:
            const EdgeInsets.only(left: 20, right: 20, top: 60, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              greeting,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search,
                  color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search properties, agriculture, goods…',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
              Icon(Icons.tune, color: Colors.grey[400], size: 18),
            ],
          ),
        ),
      );
}

// ─── Category grid ────────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.actions});
  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 0.85,
      children: actions.map((a) => _QuickActionTile(action: a)).toList(),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.go(action.route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(action.icon, color: action.color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});
  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: const Text('See all'),
          ),
        ],
      );
}

// ─── Shimmer placeholder ──────────────────────────────────────────────────────

class _HorizontalShimmer extends StatelessWidget {
  const _HorizontalShimmer();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: Colors.grey[200]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );
}

// ─── Error tile ───────────────────────────────────────────────────────────────

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Failed to load'),
          subtitle: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}

// ─── Row widgets ──────────────────────────────────────────────────────────────

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.items});
  final List<PropertyModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('No properties listed yet.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final p = items[i];
          final imgUrl = p.imageUrls.isNotEmpty ? p.imageUrls.first : null;
          return GestureDetector(
            onTap: () => ctx.go('/properties/${p.id}'),
            child: _FeaturedCard(
              imageUrl: imgUrl,
              icon: Icons.apartment_rounded,
              iconColor: AppTheme.primary,
              title: p.title,
              subtitle: p.city ?? p.address,
              price: '\$${p.price.toStringAsFixed(0)}',
              badge: p.propertyType,
            ),
          );
        },
      ),
    );
  }
}

class _AgriRow extends StatelessWidget {
  const _AgriRow({required this.items});
  final List<AgricultureListingModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('No agriculture listings yet.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final a = items[i];
          final imgUrl =
              (a.images != null && a.images!.isNotEmpty) ? a.images!.first : null;
          return GestureDetector(
            onTap: () => ctx.go('/agriculture/${a.id}'),
            child: _FeaturedCard(
              imageUrl: imgUrl,
              icon: Icons.grass_rounded,
              iconColor: const Color(0xFF388E3C),
              title: a.title,
              subtitle: a.location ?? a.category ?? '',
              price: '\$${a.pricePerUnit.toStringAsFixed(2)}/${a.unit ?? 'unit'}',
              badge: a.category,
            ),
          );
        },
      ),
    );
  }
}

class _MfgRow extends StatelessWidget {
  const _MfgRow({required this.items});
  final List<ManufacturingProductModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('No manufacturing products yet.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final m = items[i];
          final imgUrl =
              (m.images != null && m.images!.isNotEmpty) ? m.images!.first : null;
          return GestureDetector(
            onTap: () => ctx.go('/manufacturing/${m.id}'),
            child: _FeaturedCard(
              imageUrl: imgUrl,
              icon: Icons.precision_manufacturing_rounded,
              iconColor: AppTheme.secondary,
              title: m.title,
              subtitle: m.category ?? (m.isLocallyMade ? 'Locally Made' : ''),
              price: '\$${m.wholesalePrice.toStringAsFixed(2)}/${m.unit ?? 'unit'}',
              badge: m.category,
            ),
          );
        },
      ),
    );
  }
}

// ─── Featured card ────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.imageUrl,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.price,
    this.badge,
  });

  final String? imageUrl;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String price;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 175,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / placeholder
            SizedBox(
              height: 120,
              width: double.infinity,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Shimmer.fromColors(
                        baseColor: Colors.grey[200]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => _PlaceholderBox(
                        icon: icon,
                        iconColor: iconColor,
                      ),
                    )
                  : _PlaceholderBox(icon: icon, iconColor: iconColor),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12, height: 1.3),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    price,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox({required this.icon, required this.iconColor});
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
        color: iconColor.withValues(alpha: 0.07),
        child: Center(
          child: Icon(icon, size: 36, color: iconColor.withValues(alpha: 0.35)),
        ),
      );
}

