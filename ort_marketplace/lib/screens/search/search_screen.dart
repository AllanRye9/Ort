import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/app_preferences.dart';
import '../../core/listing_providers.dart';
import '../../models/models.dart';
import '../../widgets/listing_card.dart';

// ─── Filter state ─────────────────────────────────────────────────────────────

class _FilterState {
  final String query;
  final double? minPrice;
  final double? maxPrice;
  final String? location;
  final String? category;
  final String? section; // 'all', 'property', 'agriculture', 'manufacturing'
  final String? country;

  const _FilterState({
    this.query = '',
    this.minPrice,
    this.maxPrice,
    this.location,
    this.category,
    this.section,
    this.country,
  });

  _FilterState copyWith({
    String? query,
    double? minPrice,
    double? maxPrice,
    String? location,
    String? category,
    String? section,
    String? country,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearLocation = false,
    bool clearCategory = false,
    bool clearCountry = false,
  }) =>
      _FilterState(
        query: query ?? this.query,
        minPrice: clearMinPrice ? null : minPrice ?? this.minPrice,
        maxPrice: clearMaxPrice ? null : maxPrice ?? this.maxPrice,
        location: clearLocation ? null : location ?? this.location,
        category: clearCategory ? null : category ?? this.category,
        section: section ?? this.section,
        country: clearCountry ? null : country ?? this.country,
      );

  bool get hasFilters =>
      minPrice != null ||
      maxPrice != null ||
      (location?.isNotEmpty ?? false) ||
      (category?.isNotEmpty ?? false) ||
      (section != null && section != 'all') ||
      (country?.isNotEmpty ?? false);
}

final _filterProvider =
    StateProvider<_FilterState>((ref) => const _FilterState());

// ─── Combined search result ───────────────────────────────────────────────────

sealed class _SearchResult {
  const _SearchResult();
}

class _PropertyResult extends _SearchResult {
  const _PropertyResult(this.item);
  final PropertyModel item;
}

class _AgriResult extends _SearchResult {
  const _AgriResult(this.item);
  final AgricultureListingModel item;
}

class _MfgResult extends _SearchResult {
  const _MfgResult(this.item);
  final ManufacturingProductModel item;
}

// ─── Results provider ────────────────────────────────────────────────────────

final _searchResultsProvider =
    FutureProvider.autoDispose<List<_SearchResult>>((ref) async {
  final filter = ref.watch(_filterProvider);
  if (filter.query.isEmpty && !filter.hasFilters) return const [];

  final api = ref.read(apiServiceProvider);
  final section = filter.section ?? 'all';

  // Determine effective country filter: explicit > marketplace-mode default.
  String? country;
  String? excludeCountry;
  if (filter.country != null && filter.country!.isNotEmpty) {
    country = filter.country;
  } else {
    final mode = ref.read(marketplaceModeProvider);
    final userCountry = ref.read(userCountryProvider);
    final intlCountryFilter = ref.read(intlCountryFilterProvider);
    if (mode == MarketplaceMode.local) {
      country = userCountry;
    } else if (intlCountryFilter.isNotEmpty) {
      country = intlCountryFilter;
    } else {
      // International mode, no explicit intl filter – exclude the user's own
      // country so domestic-only listings are suppressed.
      excludeCountry = userCountry;
    }
  }

  final futures = <Future<List<dynamic>>>[];
  final sections = <String>[];

  if (section == 'all' || section == 'property') {
    futures.add(api.getPropertiesFiltered(
      keyword: filter.query.isNotEmpty ? filter.query : null,
      minPrice: filter.minPrice,
      maxPrice: filter.maxPrice,
      city: filter.location,
      country: country,
      excludeCountry: excludeCountry,
      limit: 50,
    ));
    sections.add('property');
  }
  if (section == 'all' || section == 'agriculture') {
    futures.add(api.getAgricultureFiltered(
      keyword: filter.query.isNotEmpty ? filter.query : null,
      minPrice: filter.minPrice,
      maxPrice: filter.maxPrice,
      location: filter.location,
      category: filter.category,
      country: country,
      excludeCountry: excludeCountry,
      limit: 50,
    ));
    sections.add('agriculture');
  }
  if (section == 'all' || section == 'manufacturing') {
    futures.add(api.getManufacturingFiltered(
      keyword: filter.query.isNotEmpty ? filter.query : null,
      minPrice: filter.minPrice,
      maxPrice: filter.maxPrice,
      location: filter.location,
      category: filter.category,
      country: country,
      excludeCountry: excludeCountry,
      limit: 50,
    ));
    sections.add('manufacturing');
  }

  final results = await Future.wait(futures);
  final combined = <_SearchResult>[];

  for (var i = 0; i < sections.length; i++) {
    switch (sections[i]) {
      case 'property':
        combined.addAll(
          results[i]
              .map((e) => _PropertyResult(PropertyModel.fromJson(e)))
              .toList(),
        );
      case 'agriculture':
        combined.addAll(
          results[i]
              .map((e) => _AgriResult(AgricultureListingModel.fromJson(e)))
              .toList(),
        );
      case 'manufacturing':
        combined.addAll(
          results[i]
              .map((e) => _MfgResult(ManufacturingProductModel.fromJson(e)))
              .toList(),
        );
    }
  }

  return combined;
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    ref.read(_filterProvider.notifier).update(
          (s) => s.copyWith(query: text),
        );
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterPanel(
        current: ref.read(_filterProvider),
        onApply: (updated) {
          ref.read(_filterProvider.notifier).state = updated;
          Navigator.of(ctx).pop();
        },
        onClear: () {
          ref.read(_filterProvider.notifier).state = _FilterState(
            query: ref.read(_filterProvider).query,
          );
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_filterProvider);
    final resultsAsync = ref.watch(_searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Search properties, agri, goods…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            filled: false,
            border: InputBorder.none,
            prefixIcon:
                Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _ctrl.clear();
                      ref
                          .read(_filterProvider.notifier)
                          .update((s) => s.copyWith(query: ''));
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _submit,
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white),
                tooltip: 'Filters',
                onPressed: _showFilters,
              ),
              if (filter.hasFilters)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Active filter chips
          if (filter.hasFilters) _FilterChips(filter: filter),

          // Results
          Expanded(
            child: (filter.query.isEmpty && !filter.hasFilters)
                ? _FeaturedPreview()
                : resultsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search_off,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                filter.query.isNotEmpty
                                    ? 'No results for "${filter.query}"'
                                    : 'No listings match your filters',
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _resultTile(ctx, items[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _resultTile(BuildContext ctx, _SearchResult r) => switch (r) {
        _PropertyResult(:final item) => ListingCard(
            icon: Icons.home,
            iconColor: Theme.of(ctx).colorScheme.primary,
            title: item.title,
            subtitle: item.city ?? item.address,
            tag: item.propertyType,
            status: item.status,
            price: formatCurrency(item.price, country: item.country),
            imageUrl:
                item.imageUrls.isNotEmpty ? item.imageUrls.first : null,
            extras: [
              if (item.bedrooms != null) '${item.bedrooms} bd',
              if (item.bathrooms != null) '${item.bathrooms} ba',
            ],
            onTap: () => ctx.go('/properties/${item.id}'),
          ),
        _AgriResult(:final item) => ListingCard(
            icon: Icons.grass,
            iconColor: Colors.green,
            title: item.title,
            subtitle: item.location ?? item.commodityType ?? '',
            tag: item.category ?? 'Agriculture',
            status: item.status,
            price:
                '${formatCurrency(item.pricePerUnit, currency: item.currency, decimals: 2)}/${item.unit ?? 'unit'}',
            imageUrl: (item.images?.isNotEmpty == true)
                ? item.images!.first
                : null,
            onTap: () => ctx.go('/agriculture/${item.id}'),
          ),
        _MfgResult(:final item) => ListingCard(
            icon: Icons.factory,
            iconColor: Colors.orange,
            title: item.title,
            subtitle: item.category ?? '',
            tag: item.category ?? 'Manufacturing',
            status: item.status,
            price:
                '${formatCurrency(item.wholesalePrice, currency: item.currency, decimals: 2)}/${item.unit ?? 'unit'}',
            imageUrl: (item.images?.isNotEmpty == true)
                ? item.images!.first
                : null,
            onTap: () => ctx.go('/manufacturing/${item.id}'),
          ),
      };
}

// ─── Featured preview (shown when no search query entered) ───────────────────

class _FeaturedPreview extends ConsumerWidget {
  const _FeaturedPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(homePropertiesProvider);
    final agriAsync = ref.watch(homeAgricultureProvider);
    final mfgAsync = ref.watch(homeMfgProvider);

    final properties = propertiesAsync.valueOrNull ?? const [];
    final agri = agriAsync.valueOrNull ?? const [];
    final mfg = mfgAsync.valueOrNull ?? const [];

    if (properties.isEmpty && agri.isEmpty && mfg.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search or apply filters to discover listings',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Discover Listings',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 12),
        if (properties.isNotEmpty) ...[
          Text('Properties',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _PreviewRow(
            items: properties.take(5).map((p) => _PreviewItem(
                  imageUrl: p.imageUrls.isNotEmpty ? p.imageUrls.first : null,
                  title: p.title,
                  subtitle: p.city ?? p.address,
                  icon: Icons.apartment,
                  iconColor: cs.primary,
                  onTap: () => context.go('/properties/${p.id}'),
                )).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (agri.isNotEmpty) ...[
          Text('Agriculture',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _PreviewRow(
            items: agri.take(5).map((a) => _PreviewItem(
                  imageUrl: a.images?.isNotEmpty == true ? a.images!.first : null,
                  title: a.title,
                  subtitle: a.location ?? a.category ?? '',
                  icon: Icons.grass,
                  iconColor: Colors.green,
                  onTap: () => context.go('/agriculture/${a.id}'),
                )).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (mfg.isNotEmpty) ...[
          Text('Manufacturing',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _PreviewRow(
            items: mfg.take(5).map((m) => _PreviewItem(
                  imageUrl: m.images?.isNotEmpty == true ? m.images!.first : null,
                  title: m.title,
                  subtitle: m.category ?? '',
                  icon: Icons.factory,
                  iconColor: Colors.orange,
                  onTap: () => context.go('/manufacturing/${m.id}'),
                )).toList(),
          ),
        ],
      ],
    );
  }
}

class _PreviewItem {
  const _PreviewItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.imageUrl,
  });
  final String? imageUrl;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.items});
  final List<_PreviewItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final item = items[i];
          return GestureDetector(
            onTap: item.onTap,
            child: SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: item.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            width: 120,
                            height: 90,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _iconPlaceholder(item),
                            placeholder: (_, __) => _iconPlaceholder(item),
                          )
                        : _iconPlaceholder(item),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _iconPlaceholder(_PreviewItem item) => Container(
        width: 120,
        height: 90,
        decoration: BoxDecoration(
          color: item.iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.icon, size: 36, color: item.iconColor.withValues(alpha: 0.5)),
      );
}

// ─── Active filter chips ──────────────────────────────────────────────────────

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.filter});
  final _FilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = <Widget>[];
    if (filter.section != null && filter.section != 'all') {
      chips.add(_Chip(
        label: filter.section!,
        onRemove: () => ref
            .read(_filterProvider.notifier)
            .update((s) => s.copyWith(section: 'all')),
      ));
    }
    if (filter.minPrice != null || filter.maxPrice != null) {
      final label = filter.minPrice != null && filter.maxPrice != null
          ? '\$${filter.minPrice!.toStringAsFixed(0)}–\$${filter.maxPrice!.toStringAsFixed(0)}'
          : filter.minPrice != null
              ? '≥\$${filter.minPrice!.toStringAsFixed(0)}'
              : '≤\$${filter.maxPrice!.toStringAsFixed(0)}';
      chips.add(_Chip(
        label: label,
        onRemove: () => ref.read(_filterProvider.notifier).update(
            (s) => s.copyWith(clearMinPrice: true, clearMaxPrice: true)),
      ));
    }
    if (filter.location?.isNotEmpty ?? false) {
      chips.add(_Chip(
        label: filter.location!,
        onRemove: () => ref
            .read(_filterProvider.notifier)
            .update((s) => s.copyWith(clearLocation: true)),
      ));
    }
    if (filter.category?.isNotEmpty ?? false) {
      chips.add(_Chip(
        label: filter.category!,
        onRemove: () => ref
            .read(_filterProvider.notifier)
            .update((s) => s.copyWith(clearCategory: true)),
      ));
    }
    if (filter.country?.isNotEmpty ?? false) {
      chips.add(_Chip(
        label: '🌍 ${filter.country!}',
        onRemove: () => ref
            .read(_filterProvider.notifier)
            .update((s) => s.copyWith(clearCountry: true)),
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(spacing: 8, children: chips),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onRemove,
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}

// ─── Filter panel ─────────────────────────────────────────────────────────────

class _FilterPanel extends StatefulWidget {
  const _FilterPanel({
    required this.current,
    required this.onApply,
    required this.onClear,
  });
  final _FilterState current;
  final void Function(_FilterState) onApply;
  final VoidCallback onClear;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  String _section = 'all';
  String? _country;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _minPriceCtrl.text = c.minPrice?.toStringAsFixed(0) ?? '';
    _maxPriceCtrl.text = c.maxPrice?.toStringAsFixed(0) ?? '';
    _locationCtrl.text = c.location ?? '';
    _categoryCtrl.text = c.category ?? '';
    _section = c.section ?? 'all';
    _country = c.country;
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _locationCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                    onPressed: widget.onClear, child: const Text('Clear all')),
              ],
            ),
            const SizedBox(height: 12),

            // Section
            const Text('Category',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in [
                  ('all', 'All'),
                  ('property', 'Properties'),
                  ('agriculture', 'Agriculture'),
                  ('manufacturing', 'Manufacturing'),
                ])
                  ChoiceChip(
                    label: Text(s.$2),
                    selected: _section == s.$1,
                    onSelected: (_) => setState(() => _section = s.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Price range
            const Text('Price Range',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min \$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max \$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location
            const Text('Location / Region',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'City, region or country',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Category keyword
            const Text('Sub-category',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'e.g. grains, textiles, apartment',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Country
            const Text('Country',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('All countries'),
                  selected: _country == null || _country!.isEmpty,
                  onSelected: (_) => setState(() => _country = null),
                ),
                ...kInternationalCountries.map(
                  (c) => ChoiceChip(
                    label: Text(c),
                    selected: _country == c,
                    onSelected: (_) => setState(() => _country = c),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                final minP = double.tryParse(_minPriceCtrl.text);
                final maxP = double.tryParse(_maxPriceCtrl.text);
                if (minP != null && maxP != null && minP > maxP) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Min price cannot be greater than max price.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                widget.onApply(_FilterState(
                  query: widget.current.query,
                  minPrice: minP,
                  maxPrice: maxP,
                  location: _locationCtrl.text.trim().isNotEmpty
                      ? _locationCtrl.text.trim()
                      : null,
                  category: _categoryCtrl.text.trim().isNotEmpty
                      ? _categoryCtrl.text.trim()
                      : null,
                  section: _section,
                  country: (_country != null && _country!.isNotEmpty)
                      ? _country
                      : null,
                ));
              },
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
