import 'dart:async';
import 'dart:math' show cos, pi, sin;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api_service.dart';
import '../../core/app_preferences.dart';
import '../../core/auth_provider.dart';
import '../../core/listing_providers.dart';
import '../../core/location_service.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

// Provider for current user (for avatar in hero banner)
final _homeUserProvider = FutureProvider.autoDispose<UserModel?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return null;
  try {
    final data = await ref.read(apiServiceProvider).getMe();
    return UserModel.fromJson(data);
  } catch (_) {
    return null;
  }
});

// Provider for wallet points displayed in the app bar
final _homeWalletPointsProvider = FutureProvider.autoDispose<int?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return null;
  try {
    final data = await ref.read(apiServiceProvider).getMyWallet();
    return WalletModel.fromJson(data).points;
  } catch (_) {
    return null;
  }
});

// ─── Distance helper ──────────────────────────────────────────────────────────

/// Returns the distance in km from [userLoc] to [lat]/[lon], or null if any
/// value is missing.
double? _distanceFromUser(
    (double, double)? userLoc, double? lat, double? lon) {
  if (userLoc == null || lat == null || lon == null) return null;
  return haversineKm(userLoc.$1, userLoc.$2, lat, lon);
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

  // true when the device's location service (GPS toggle) is off
  bool _locationServiceOff = false;
  // whether the user dismissed the location-service-off banner
  bool _locationBannerDismissed = false;
  // whether the one-time GPS-off dialog has been shown this session
  bool _locationDialogShown = false;

  // Position used for the most recent sort, used to detect >500 m moves.
  (double, double)? _lastSortedLoc;
  // true when user has moved >500 m since the last sort
  bool _showRefreshResults = false;

  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    // Request location exactly once at startup.
    _initLocation();
    // Show marketplace-mode selection the first time the user reaches the home
    // screen (i.e. they have never chosen local vs international before).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(marketplaceModeProvider.notifier);
      if (!notifier.everSelected) {
        _showModeSelectionDialog();
      }
    });
    // Listen for the device-level location service being toggled on/off.
    // getServiceStatusStream is not supported on web.
    if (!kIsWeb) {
      _serviceStatusSub =
          Geolocator.getServiceStatusStream().listen(_onServiceStatusChanged);
    }
  }

  void _onServiceStatusChanged(ServiceStatus status) {
    if (status == ServiceStatus.enabled) {
      // Location services were turned on – retry and re-sort listings.
      setState(() {
        _locationServiceOff = false;
        _locationBannerDismissed = false;
      });
      _initLocation();
    } else {
      setState(() => _locationServiceOff = true);
    }
  }

  Future<void> _initLocation() async {
    // Skip if we already have a position cached.
    if (ref.read(userLocationProvider) != null) return;

    // Check whether the device's location service (GPS) is enabled first.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      setState(() => _locationServiceOff = true);
      // Show a one-time dialog prompting the user to enable GPS.
      if (!_locationDialogShown) {
        setState(() => _locationDialogShown = true);
        _showGpsOffDialog();
      }
      return;
    }

    try {
      final pos = await LocationService.instance.requestAndGetPosition();
      if (!mounted) return;
      if (pos != null) {
        final loc = (pos.latitude, pos.longitude);
        ref.read(userLocationProvider.notifier).state = loc;
        setState(() {
          _locationServiceOff = false;
          _lastSortedLoc = loc;
        });
        _startPositionTracking();
      }
      // If permission denied (once), silently skip – no banner shown.
    } on LocationPermissionDeniedException {
      // Permission permanently denied – show a one-time dialog to open settings.
      if (!mounted) return;
      if (!_locationDialogShown) {
        setState(() => _locationDialogShown = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location permission has been permanently denied. '
                'To see listings near you, open app settings and allow location access.\n\n'
                'Listings will be shown in default order until permission is granted.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ).then((open) async {
            if (open == true) {
              await Geolocator.openAppSettings();
            }
          });
        });
      }
    } catch (_) {
      // Unexpected error – silently skip.
    }
  }

  /// Shows a dialog when GPS is off, giving the user Cancel/Accept options.
  void _showGpsOffDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Location services are off'),
          content: const Text(
            'Location services are turned off. Would you like to enable them '
            'to see listings near you?\n\n'
            'If you cancel, listings will be shown in default order '
            '(most recent first).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Enable GPS'),
            ),
          ],
        ),
      ).then((accepted) async {
        if (accepted == true) {
          try {
            await Geolocator.openLocationSettings();
          } catch (_) {}
        } else {
          // User declined – show dismissible banner but do not re-prompt.
          if (mounted) setState(() => _locationBannerDismissed = false);
        }
      });
    });
  }

  /// Starts a position stream to detect when the user has moved >500 m.
  /// Position streaming with distanceFilter is not supported on web.
  void _startPositionTracking() {
    if (kIsWeb) return;
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100, // receive updates every 100 m
      ),
    ).listen((pos) {
      if (!mounted) return;
      final current = (pos.latitude, pos.longitude);
      final last = _lastSortedLoc;
      if (last != null) {
        final dist = haversineKm(last.$1, last.$2, current.$1, current.$2);
        if (dist >= 0.5 && !_showRefreshResults) {
          setState(() => _showRefreshResults = true);
        }
      }
    });
  }

  /// Re-sorts listings based on the current position.
  Future<void> _refreshResults() async {
    final pos = await LocationService.instance.requestAndGetPosition();
    if (!mounted) return;
    if (pos != null) {
      final loc = (pos.latitude, pos.longitude);
      ref.read(userLocationProvider.notifier).state = loc;
      setState(() {
        _lastSortedLoc = loc;
        _showRefreshResults = false;
      });
    }
  }

  /// Shows the marketplace-mode selection dialog.  Called once on first login
  /// and also available via the settings screen.
  void _showModeSelectionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ModeSelectionDialog(
        onSelected: (mode) {
          ref.read(marketplaceModeProvider.notifier).setMode(mode);
        },
      ),
    );
  }

  @override
  void dispose() {
    _serviceStatusSub?.cancel();
    _positionSub?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(sortedHomePropertiesProvider);
    final agricultureAsync = ref.watch(sortedHomeAgricultureProvider);
    final mfgAsync = ref.watch(sortedHomeMfgProvider);
    final servicesAsync = ref.watch(sortedHomeServicesProvider);
    final userLoc = ref.watch(userLocationProvider);
    final auth = ref.watch(authProvider);
    final role = auth.role ?? 'user';
    final currentUser = ref.watch(_homeUserProvider).valueOrNull;
    final walletPoints = ref.watch(_homeWalletPointsProvider).valueOrNull;
    final marketplaceMode = ref.watch(marketplaceModeProvider);
    final distanceUnit = ref.watch(distanceUnitProvider);

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
          ref.invalidate(homeServicesProvider);
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
                  avatarUrl: currentUser?.avatarUrl,
                  onAvatarTap: () => context.go('/profile'),
                  marketplaceMode: marketplaceMode,
                ),
              ),
              actions: [
                // ── Wallet points badge ──────────────────────────────────
                if (auth.isAuthenticated)
                  GestureDetector(
                    onTap: () => context.go('/wallet'),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 14),
                          const SizedBox(width: 4),
                          Text(
                            walletPoints != null
                                ? '$walletPoints pts'
                                : '— pts',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () => context.go('/notifications'),
                ),
              ],
              title: const Text('Ort Marketplace',
                  style: TextStyle(color: Colors.white, fontSize: 17)),
            ),

            // ── Search bar + location banners + radius filter ───────────────
            SliverToBoxAdapter(
              child: _ContentWrapper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchBar(onTap: () => context.go('/search')),
                    const SizedBox(height: 8),
                    // Location service is OFF – non-blocking dismissible banner
                    if (_locationServiceOff && !_locationBannerDismissed)
                      _LocationBanner(
                        icon: Icons.location_off_outlined,
                        message: 'Turn on GPS to find listings near you.',
                        actionLabel: 'Open Settings',
                        onAction: () async {
                          try {
                            await Geolocator.openLocationSettings();
                          } catch (_) {}
                        },
                        onDismiss: () =>
                            setState(() => _locationBannerDismissed = true),
                      ),
                    // Refresh results banner when user has moved >500 m
                    if (_showRefreshResults)
                      _LocationBanner(
                        icon: Icons.refresh_outlined,
                        message: 'You\'ve moved! Refresh to see listings near your new location.',
                        actionLabel: 'Refresh',
                        onAction: _refreshResults,
                        onDismiss: () =>
                            setState(() => _showRefreshResults = false),
                      ),
                    // Radius filter logic runs in background; UI chips removed.
                  ],
                ),
              ),
            ),

            // ── AI Assistant ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                child: _ContentWrapper(child: const _AiWidget()),
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
                      price: formatCurrencyForMode(p.price, country: p.country, mode: marketplaceMode),
                      badge: p.propertyType,
                      distanceKm: _distanceFromUser(userLoc, p.latitude, p.longitude),
                      distanceUnit: distanceUnit,
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
                            '${formatCurrencyForMode(a.pricePerUnit, currency: a.currency, decimals: 2, mode: marketplaceMode)}/${a.unit ?? 'unit'}',
                        badge: a.category,
                        distanceKm: _distanceFromUser(userLoc, a.latitude, a.longitude),
                        distanceUnit: distanceUnit,
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
                padding: const EdgeInsets.only(bottom: 24),
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
                            '${formatCurrencyForMode(m.wholesalePrice, currency: m.currency, decimals: 2, mode: marketplaceMode)}/${m.unit ?? 'unit'}',
                        badge: m.category,
                        distanceKm: _distanceFromUser(userLoc, m.latitude, m.longitude),
                        distanceUnit: distanceUnit,
                        onTap: () => ctx.go('/manufacturing/${m.id}'),
                      );
                    },
                    emptyText: 'No manufacturing products yet.',
                  ),
                ),
              ),
            ),

            // ── Manufacturing Services ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _ContentWrapper(
                child: _SectionHeader(
                  title: 'Manufacturing Services',
                  onSeeAll: () => context.go('/manufacturing'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: servicesAsync.when(
                  loading: () => const _HorizontalShimmer(),
                  error: (e, _) => _ErrorTile(message: e.toString()),
                  data: (items) => _FeaturedSection<ManufacturingServiceModel>(
                    items: items,
                    cardBuilder: (ctx, s) {
                      final imgUrl = (s.images != null && s.images!.isNotEmpty)
                          ? s.images!.first
                          : null;
                      return _FeaturedCard(
                        imageUrl: imgUrl,
                        icon: Icons.build_rounded,
                        iconColor: const Color(0xFF0288D1),
                        title: s.title,
                        subtitle: s.serviceType ?? s.location ?? '',
                        price:
                            '${formatCurrencyForMode(s.price, currency: s.currency, decimals: 2, mode: marketplaceMode)}/${s.pricingUnit ?? 'service'}',
                        badge: s.serviceType,
                        distanceKm: _distanceFromUser(userLoc, s.latitude, s.longitude),
                        distanceUnit: distanceUnit,
                        onTap: () => ctx.go('/manufacturing/service/${s.id}'),
                      );
                    },
                    emptyText: 'No manufacturing services yet.',
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
    this.avatarUrl,
    this.onAvatarTap,
    this.marketplaceMode,
  });
  final String greeting;
  final String subtitle;
  final String role;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final MarketplaceMode? marketplaceMode;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
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
  Widget build(BuildContext context) {
    final roleIcon = Icon(_roleIcon, color: Colors.white, size: 28);
    return Container(
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
                  if (widget.marketplaceMode != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.marketplaceMode == MarketplaceMode.international
                                ? Icons.public
                                : Icons.place,
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.marketplaceMode == MarketplaceMode.international
                                ? 'International · USD'
                                : 'Local',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Profile image / spinning wheel badge
            RotationTransition(
              turns: _spinCtrl,
              child: GestureDetector(
                onTap: widget.onAvatarTap,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: widget.avatarUrl!,
                            fit: BoxFit.cover,
                            width: 52,
                            height: 52,
                            placeholder: (_, __) => roleIcon,
                            errorWidget: (_, __, ___) => roleIcon,
                          ),
                        )
                      : roleIcon,
                ),
              ),
            ),
          ],
        ),
      );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.search, color: cs.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search properties, agriculture, goods…',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, color: cs.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

// ─── Location banner ──────────────────────────────────────────────────────────

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: TextStyle(fontSize: 12, color: cs.primary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            color: cs.onSurface.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}

// ─── Radius filter chips ──────────────────────────────────────────────────────

class _RadiusFilter extends ConsumerStatefulWidget {
  const _RadiusFilter();

  @override
  ConsumerState<_RadiusFilter> createState() => _RadiusFilterState();
}

class _RadiusFilterState extends ConsumerState<_RadiusFilter> {
  static const _presets = [1.0, 5.0, 10.0, 20.0, 50.0];
  final _customCtrl = TextEditingController();
  bool _showCustom = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _setRadius(double km) {
    ref.read(radiusFilterProvider.notifier).state = km;
  }

  @override
  Widget build(BuildContext context) {
    final radius = ref.watch(radiusFilterProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.radar, size: 13, color: cs.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text(
              'Show listings within:',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final km in _presets) ...[
                FilterChip(
                  label: Text(
                    km == km.truncateToDouble()
                        ? '${km.toStringAsFixed(0)} km'
                        : '${km.toStringAsFixed(1)} km',
                  ),
                  selected: radius == km && !_showCustom,
                  onSelected: (_) {
                    setState(() => _showCustom = false);
                    _setRadius(km);
                  },
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: (radius == km && !_showCustom) ? cs.onPrimary : cs.onSurface,
                  ),
                  selectedColor: cs.primary,
                  showCheckmark: false,
                ),
                const SizedBox(width: 6),
              ],
              FilterChip(
                label: const Text('Custom'),
                selected: _showCustom,
                onSelected: (_) => setState(() => _showCustom = !_showCustom),
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: _showCustom ? cs.onPrimary : cs.onSurface,
                ),
                selectedColor: cs.primary,
                showCheckmark: false,
              ),
            ],
          ),
        ),
        if (_showCustom) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _customCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 35',
                    suffixText: 'km',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (v) {
                    final km = double.tryParse(v);
                    if (km != null && km > 0) _setRadius(km);
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final km = double.tryParse(_customCtrl.text);
                  if (km != null && km > 0) _setRadius(km);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Go'),
              ),
            ],
          ),
        ],
      ],
    );
  }
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
        child: Text(emptyText,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                // pad stores left+right as a sum; divide by 2 to get per-side value
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
    this.distanceKm,
    this.distanceUnit = DistanceUnit.km,
    this.onTap,
  });

  final String? imageUrl;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String price;
  final String? badge;
  /// Distance in km from user location. Null when location is not available.
  final double? distanceKm;
  /// Unit to display the distance in.
  final DistanceUnit distanceUnit;
  final VoidCallback? onTap;

  String get _distanceLabel => formatDistance(distanceKm, distanceUnit);

  void _openImagePreview(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: context.isWide ? null : 175, // 175 dp fits ~2 cards on a 360dp phone
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
                GestureDetector(
                  onTap: imageUrl != null
                      ? () => _openImagePreview(context, imageUrl!)
                      : onTap,
                  child: SizedBox(
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
                ),
                // Category badge (bottom-right)
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
                // Distance badge (top-left)
                if (distanceKm != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me,
                              size: 9, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            _distanceLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.3,
                        color: cs.onSurface),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    price,
                    style: TextStyle(
                      color: cs.primary,
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

class _AiWidget extends ConsumerStatefulWidget {
  const _AiWidget();

  @override
  ConsumerState<_AiWidget> createState() => _AiWidgetState();
}

class _AiWidgetState extends ConsumerState<_AiWidget> {
  void _openDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => const _AiDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _openDialog,
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
                    const Text('Tap to search listings with AI',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── AI popup dialog ──────────────────────────────────────────────────────────

class _AiDialog extends ConsumerStatefulWidget {
  const _AiDialog();

  @override
  ConsumerState<_AiDialog> createState() => _AiDialogState();
}

class _AiDialogState extends ConsumerState<_AiDialog>
    with SingleTickerProviderStateMixin {
  bool _scanning = false;
  final _ctrl = TextEditingController();
  late final AnimationController _radarCtrl;

  static const _scanDuration = Duration(milliseconds: 1600);
  static const _minKeywordLength = 3;
  static const _sectionWords = {
    'properties', 'property', 'agriculture', 'agricultural', 'farming',
    'farm', 'manufacturing', 'manufacture', 'products', 'product',
    'services', 'service',
  };

  final List<_AiMessage> _messages = [
    const _AiMessage(
        role: 'assistant',
        text: 'Hi! I\'m your Ort AI assistant 🤖\nTap a popular topic or ask me anything about listings on this page.'),
  ];

  static const _popularQueries = [
    ('🏠 Properties', 'properties'),
    ('🌾 Agriculture', 'agriculture'),
    ('🏭 Manufacturing', 'manufacturing'),
    ('🔧 Services', 'services'),
  ];

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: _scanDuration,
    );
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? query]) async {
    final text = (query ?? _ctrl.text).trim();
    if (text.isEmpty || _scanning) return;

    setState(() {
      _messages.add(_AiMessage(role: 'user', text: text));
      _scanning = true;
    });
    _ctrl.clear();

    _radarCtrl.repeat();
    await Future.delayed(_scanDuration);
    _radarCtrl
      ..stop()
      ..reset();

    if (!mounted) return;

    final lower = text.toLowerCase();
    final props = ref.read(sortedHomePropertiesProvider).valueOrNull ?? [];
    final agri = ref.read(sortedHomeAgricultureProvider).valueOrNull ?? [];
    final mfg = ref.read(sortedHomeMfgProvider).valueOrNull ?? [];
    final svc = ref.read(sortedHomeServicesProvider).valueOrNull ?? [];
    final mode = ref.read(marketplaceModeProvider);

    final targetsProps = _sectionMatch(lower, ['propert']);
    final targetsAgri = _sectionMatch(lower, ['agricult', 'farm']);
    final targetsMfg = _sectionMatch(lower, ['manufactur', 'product']);
    final targetsSvc = _sectionMatch(lower, ['service']);
    final anySection = targetsProps || targetsAgri || targetsMfg || targetsSvc;

    final keywords = _keywords(lower);
    final results = <String>[];

    if (targetsProps || (!anySection && keywords.isNotEmpty)) {
      for (final p in props) {
        if (keywords.isEmpty ||
            _keywordMatch(keywords, [p.title, p.city, p.address, p.propertyType])) {
          results.add(
              '🏠 ${p.title} · ${p.city ?? p.address} · ${formatCurrencyForMode(p.price, country: p.country, mode: mode)}');
        }
      }
    }
    if (targetsAgri || (!anySection && keywords.isNotEmpty)) {
      for (final a in agri) {
        if (keywords.isEmpty ||
            _keywordMatch(keywords, [a.title, a.category, a.location])) {
          results.add(
              '🌾 ${a.title} · ${a.location ?? a.category ?? ''} · ${formatCurrencyForMode(a.pricePerUnit, currency: a.currency, decimals: 2, mode: mode)}/${a.unit ?? 'unit'}');
        }
      }
    }
    if (targetsMfg || (!anySection && keywords.isNotEmpty)) {
      for (final m in mfg) {
        if (keywords.isEmpty ||
            _keywordMatch(keywords, [m.title, m.category])) {
          results.add(
              '🏭 ${m.title} · ${m.category ?? ''} · ${formatCurrencyForMode(m.wholesalePrice, currency: m.currency, decimals: 2, mode: mode)}/${m.unit ?? 'unit'}');
        }
      }
    }
    if (targetsSvc || (!anySection && keywords.isNotEmpty)) {
      for (final s in svc) {
        if (keywords.isEmpty ||
            _keywordMatch(keywords, [s.title, s.serviceType, s.location])) {
          results.add(
              '🔧 ${s.title} · ${s.serviceType ?? s.location ?? ''} · ${formatCurrencyForMode(s.price, currency: s.currency, decimals: 2, mode: mode)}/${s.pricingUnit ?? 'service'}');
        }
      }
    }

    final response = results.isNotEmpty
        ? 'Found ${results.length} match${results.length == 1 ? '' : 'es'} on this page:\n\n${results.take(5).join('\n')}'
        : '💡 No matches found for "$text". Try "properties", "agriculture", "manufacturing", or "services".';

    setState(() {
      _scanning = false;
      _messages.add(_AiMessage(role: 'assistant', text: response));
    });
  }

  bool _sectionMatch(String lower, List<String> prefixes) =>
      prefixes.any((p) => lower.contains(p));

  List<String> _keywords(String lower) {
    return lower
        .split(RegExp(r'\s+'))
        .where((w) => w.length > _minKeywordLength && !_sectionWords.contains(w))
        .toList();
  }

  bool _keywordMatch(List<String> keywords, List<String?> fields) {
    for (final field in fields) {
      if (field == null) continue;
      final f = field.toLowerCase();
      if (keywords.any((k) => f.contains(k))) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
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
                        const Text('Search listings with AI',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Popular chips ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _popularQueries
                    .map((q) => ActionChip(
                          label: Text(q.$1,
                              style: const TextStyle(fontSize: 12)),
                          onPressed: _scanning ? null : () => _send(q.$2),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              cs.primary.withValues(alpha: 0.08),
                          side: BorderSide(
                              color: cs.primary.withValues(alpha: 0.2)),
                        ))
                    .toList(),
              ),
            ),

            // ── Radar / Messages ──────────────────────────────────────────────
            if (_scanning)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _radarCtrl,
                      builder: (_, __) => CustomPaint(
                        size: const Size(120, 120),
                        painter: _RadarPainter(
                          progress: _radarCtrl.value,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scanning page…',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 200,
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
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Text(m.text,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    );
                  },
                ),
              ),

            // ── Input row ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
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
                      enabled: !_scanning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send, size: 18),
                    onPressed: _scanning ? null : _send,
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

class _AiMessage {
  const _AiMessage({required this.role, required this.text});
  final String role;
  final String text;
}

// ─── Radar painter ────────────────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.progress, required this.color});
  final double progress; // 0.0 – 1.0 (AnimationController.value)
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    // Grid circles
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, gridPaint);
    }

    // Cross hairs
    final hairPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), hairPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), hairPaint);

    // Sweep gradient (trailing arc)
    final sweepAngle = progress * 2 * pi - pi / 2;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - pi / 2,
        endAngle: sweepAngle,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.30),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      sweepAngle - pi / 2,
      pi / 2,
      true,
      sweepPaint,
    );
    canvas.restore();

    // Sweep line
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      center,
      Offset(center.dx + radius * cos(sweepAngle),
          center.dy + radius * sin(sweepAngle)),
      linePaint,
    );

    // Blips – fixed angular positions that light up as the sweep passes
    const blips = [
      (0.15, 0.45), (0.38, 0.65), (0.55, 0.30),
      (0.72, 0.55), (0.88, 0.40),
    ];
    const blipFadeInEnd = 0.05;   // fraction of rotation for full brightness
    const maxBlipAlpha = 0.9;
    const blipFadeOutSpan = 1.0 - blipFadeInEnd;
    for (final (frac, r) in blips) {
      final blipAngle = frac * 2 * pi - pi / 2;
      final blipProgress = (progress - frac + 1.0) % 1.0;
      // Fade in quickly, then decay slowly over the full rotation
      final alpha = blipProgress < blipFadeInEnd
          ? (blipProgress / blipFadeInEnd) * maxBlipAlpha
          : (maxBlipAlpha * (1.0 - (blipProgress - blipFadeInEnd) / blipFadeOutSpan))
              .clamp(0.0, maxBlipAlpha);
      final blipPaint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(center.dx + radius * r * cos(blipAngle),
            center.dy + radius * r * sin(blipAngle)),
        3.5,
        blipPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}

// ─── Mode selection dialog ────────────────────────────────────────────────────

/// Full-screen dialog shown on first login to let the user choose between
/// Local and International marketplace mode.
class _ModeSelectionDialog extends StatefulWidget {
  const _ModeSelectionDialog({required this.onSelected});

  final ValueChanged<MarketplaceMode> onSelected;

  @override
  State<_ModeSelectionDialog> createState() => _ModeSelectionDialogState();
}

class _ModeSelectionDialogState extends State<_ModeSelectionDialog>
    with SingleTickerProviderStateMixin {
  MarketplaceMode? _selected;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selected == null) return;
    widget.onSelected(_selected!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLocal = _selected == MarketplaceMode.local;
    final isIntl = _selected == MarketplaceMode.international;

    return Dialog.fullscreen(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo + title ──────────────────────────────────────────
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            size: 34, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Choose your marketplace',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can change this anytime in Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.55)),
                    ),
                    const SizedBox(height: 36),

                    // ── Local card ─────────────────────────────────────────────
                    _ModeCard(
                      selected: isLocal,
                      onTap: () => setState(() => _selected = MarketplaceMode.local),
                      icon: Icons.place_rounded,
                      iconBgColor: AppTheme.primary.withValues(alpha: 0.12),
                      iconColor: AppTheme.primary,
                      title: 'Local',
                      subtitle:
                          'Browse your local market. Prices in UGX, AED or USD based on your location.',
                      flag: '🇺🇬',
                    ),
                    const SizedBox(height: 16),

                    // ── International card ─────────────────────────────────────
                    _ModeCard(
                      selected: isIntl,
                      onTap: () => setState(
                          () => _selected = MarketplaceMode.international),
                      icon: Icons.public_rounded,
                      iconBgColor: const Color(0xFF0288D1).withValues(alpha: 0.12),
                      iconColor: const Color(0xFF0288D1),
                      title: 'International',
                      subtitle:
                          'Import & export between Uganda and UAE. All prices shown in US Dollars (USD).',
                      flag: '🇺🇬 ↔ 🇦🇪',
                    ),
                    const Spacer(),

                    // ── Confirm button ─────────────────────────────────────────
                    ElevatedButton(
                      onPressed: _selected != null ? _confirm : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Continue',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.flag,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String flag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 2.5 : 1.5,
        ),
        color: selected
            ? cs.primary.withValues(alpha: 0.06)
            : cs.surface,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(flag, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
