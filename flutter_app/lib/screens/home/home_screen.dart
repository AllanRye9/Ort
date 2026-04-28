import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/auth_provider.dart';
import '../../core/listing_providers.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

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
    final propertiesAsync = ref.watch(homePropertiesProvider);
    final agricultureAsync = ref.watch(homeAgricultureProvider);
    final mfgAsync = ref.watch(homeMfgProvider);
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
          ref.invalidate(homePropertiesProvider);
          ref.invalidate(homeAgricultureProvider);
          ref.invalidate(homeMfgProvider);
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
                  role: role,
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
              child: _ContentWrapper(
                child: _SearchBar(onTap: () => context.go('/search')),
              ),
            ),

            // ── AI Assistant ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                child: _ContentWrapper(child: const _AiWidget()),
              ),
            ),

            // ── Role-specific quick actions ──────────────────────────────────
            SliverToBoxAdapter(
              child: _ContentWrapper(
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
              child: _ContentWrapper(
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
                  data: (items) => _FeaturedSection<PropertyModel>(
                    items: items,
                    cardBuilder: (ctx, p) => _FeaturedCard(
                      imageUrl: p.imageUrls.isNotEmpty ? p.imageUrls.first : null,
                      icon: Icons.apartment_rounded,
                      iconColor: AppTheme.primary,
                      title: p.title,
                      subtitle: p.city ?? p.address,
                      price: '\$${p.price.toStringAsFixed(0)}',
                      badge: p.propertyType,
                      onTap: () => ctx.go('/properties/${p.id}'),
                    ),
                    emptyText: 'No properties listed yet.',
                  ),
                ),
              ),
            ),

            // ── Agriculture ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ContentWrapper(
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
                  data: (items) => _FeaturedSection<AgricultureListingModel>(
                    items: items,
                    cardBuilder: (ctx, a) {
                      final imgUrl = (a.images != null && a.images!.isNotEmpty)
                          ? a.images!.first
                          : null;
                      return _FeaturedCard(
                        imageUrl: imgUrl,
                        icon: Icons.grass_rounded,
                        iconColor: const Color(0xFF388E3C),
                        title: a.title,
                        subtitle: a.location ?? a.category ?? '',
                        price:
                            '\$${a.pricePerUnit.toStringAsFixed(2)}/${a.unit ?? 'unit'}',
                        badge: a.category,
                        onTap: () => ctx.go('/agriculture/${a.id}'),
                      );
                    },
                    emptyText: 'No agriculture listings yet.',
                  ),
                ),
              ),
            ),

            // ── Manufacturing ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ContentWrapper(
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
                  data: (items) => _FeaturedSection<ManufacturingProductModel>(
                    items: items,
                    cardBuilder: (ctx, m) {
                      final imgUrl = (m.images != null && m.images!.isNotEmpty)
                          ? m.images!.first
                          : null;
                      return _FeaturedCard(
                        imageUrl: imgUrl,
                        icon: Icons.precision_manufacturing_rounded,
                        iconColor: AppTheme.secondary,
                        title: m.title,
                        subtitle:
                            m.category ?? (m.isLocallyMade ? 'Locally Made' : ''),
                        price:
                            '\$${m.wholesalePrice.toStringAsFixed(2)}/${m.unit ?? 'unit'}',
                        badge: m.category,
                        onTap: () => ctx.go('/manufacturing/${m.id}'),
                      );
                    },
                    emptyText: 'No manufacturing products yet.',
                  ),
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

class _HeroBanner extends StatefulWidget {
  const _HeroBanner({
    required this.greeting,
    required this.subtitle,
    required this.role,
  });
  final String greeting;
  final String subtitle;
  final String role;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim =
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  IconData get _roleIcon {
    switch (widget.role) {
      case 'agent':
        return Icons.real_estate_agent;
      case 'company':
        return Icons.business;
      case 'organization':
        return Icons.account_balance;
      default:
        return Icons.storefront_rounded;
    }
  }

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.greeting,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // Pulsing icon badge
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: 0.92 + 0.08 * _pulseAnim.value,
                child: child,
              ),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 2),
                ),
                child: Icon(_roleIcon, color: Colors.white, size: 28),
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

// ─── Quick-actions grid ───────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.actions});
  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    // On wide screens show all actions in one row; on mobile cap at 4 per row.
    final cols = context.isWide ? actions.length : 4;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 0.85,
      children: List.generate(
        actions.length,
        (i) => _AnimatedEntry(
          delay: Duration(milliseconds: 80 * i),
          child: _QuickActionTile(action: actions[i]),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.action});
  final _QuickAction action;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) async {
          await _scaleCtrl.reverse();
          if (mounted) context.go(widget.action.route);
        },
        onTapCancel: () => _scaleCtrl.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (_, child) =>
              Transform.scale(scale: _scaleAnim.value, child: child),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.action.color.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(widget.action.icon,
                    color: widget.action.color, size: 26),
              ),
              const SizedBox(height: 6),
              Text(
                widget.action.label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
}

// ─── Animated entry wrapper ───────────────────────────────────────────────────

class _AnimatedEntry extends StatefulWidget {
  const _AnimatedEntry({required this.child, required this.delay});
  final Widget child;
  final Duration delay;

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
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
        height: 220,
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

// ─── Content wrapper (centres content with max-width on wide screens) ─────────

class _ContentWrapper extends StatelessWidget {
  const _ContentWrapper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = context.contentPadding;
    if (!context.isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: child,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.maxContentWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: pad.left, vertical: pad.top),
          child: child,
        ),
      ),
    );
  }
}

// ─── Generic featured section ──────────────────────────────────────────────────

class _FeaturedSection<T> extends StatelessWidget {
  const _FeaturedSection({
    required this.items,
    required this.cardBuilder,
    required this.emptyText,
  });

  final List<T> items;
  final Widget Function(BuildContext ctx, T item) cardBuilder;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(emptyText, style: const TextStyle(color: Colors.grey)),
      );
    }

    // On wide screens render a horizontal wrap/grid; on narrow keep scrolling row.
    if (context.isWide) {
      final cols = context.gridColumns;
      final pad = context.contentPadding;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.maxContentWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: pad.horizontal / 2, vertical: 0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                childAspectRatio: 0.78,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length > (cols * 2) ? cols * 2 : items.length,
              itemBuilder: (ctx, i) => _AnimatedEntry(
                delay: Duration(milliseconds: 60 * i),
                child: cardBuilder(ctx, items[i]),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) => _AnimatedEntry(
          delay: Duration(milliseconds: 60 * i),
          child: cardBuilder(ctx, items[i]),
        ),
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
    this.onTap,
  });

  final String? imageUrl;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String price;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.isWide ? null : 175,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / placeholder
            Stack(
              children: [
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
                // Category badge
                if (badge != null && badge!.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
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


// ─── AI Assistant widget ─────────────────────────────────────────────────────

class _AiWidget extends StatefulWidget {
  const _AiWidget();

  @override
  State<_AiWidget> createState() => _AiWidgetState();
}

class _AiWidgetState extends State<_AiWidget> {
  bool _expanded = false;
  final _ctrl = TextEditingController();
  final List<_AiMessage> _messages = [
    const _AiMessage(
        role: 'assistant',
        text: 'Hi! I\'m your Ort AI assistant 🤖\nAsk me anything about properties, agriculture, or manufacturing.'),
  ];

  static const _freeResponses = {
    'property': '🏠 I found several properties in your area. Try filtering by price or location for better results.',
    'agriculture': '🌾 Agriculture listings include grains, livestock, and produce. Use the search to find what you need.',
    'manufacturing': '🏭 We have many manufacturing products including textiles and processed goods.',
    'price': '💰 Prices vary by category. Use the price filter in Search to narrow results.',
    'help': '👋 I can help you find listings, understand pricing, or navigate the app. What do you need?',
    'hello': '👋 Hello! How can I help you today?',
    'hi': '👋 Hi there! Ask me about properties, agriculture, or manufacturing.',
  };

  static const _defaultResponse =
      '💡 Try asking about "properties", "agriculture", "manufacturing", or "price". For advanced AI features, upgrade to Pro.';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_AiMessage(role: 'user', text: text));
      final lower = text.toLowerCase();
      // Collect all matching responses and join them, falling back to the default.
      final matches = _freeResponses.entries
          .where((e) => lower.contains(e.key))
          .map((e) => e.value)
          .toList();
      final response = matches.isNotEmpty
          ? matches.join('\n\n')
          : _defaultResponse;
      _messages.add(_AiMessage(role: 'assistant', text: response));
    });
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Ort AI',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Free',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.green)),
                            ),
                          ],
                        ),
                        const Text('Ask me about listings',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            SizedBox(
              height: 180,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (ctx, i) {
                  final m = _messages[i];
                  final isUser = m.role == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(ctx).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isUser
                            ? cs.primary.withValues(alpha: 0.15)
                            : cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Text(m.text, style: const TextStyle(fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Ask something…',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send, size: 18),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiMessage {
  const _AiMessage({required this.role, required this.text});
  final String role;
  final String text;
}
