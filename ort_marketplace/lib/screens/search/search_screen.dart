import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
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

  const _FilterState({
    this.query = '',
    this.minPrice,
    this.maxPrice,
    this.location,
    this.category,
    this.section,
  });

  _FilterState copyWith({
    String? query,
    double? minPrice,
    double? maxPrice,
    String? location,
    String? category,
    String? section,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearLocation = false,
    bool clearCategory = false,
  }) =>
      _FilterState(
        query: query ?? this.query,
        minPrice: clearMinPrice ? null : minPrice ?? this.minPrice,
        maxPrice: clearMaxPrice ? null : maxPrice ?? this.maxPrice,
        location: clearLocation ? null : location ?? this.location,
        category: clearCategory ? null : category ?? this.category,
        section: section ?? this.section,
      );

  bool get hasFilters =>
      minPrice != null ||
      maxPrice != null ||
      (location?.isNotEmpty ?? false) ||
      (category?.isNotEmpty ?? false) ||
      (section != null && section != 'all');
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

  final futures = <Future<List<dynamic>>>[];
  final sections = <String>[];

  if (section == 'all' || section == 'property') {
    futures.add(api.getPropertiesFiltered(
      keyword: filter.query.isNotEmpty ? filter.query : null,
      minPrice: filter.minPrice,
      maxPrice: filter.maxPrice,
      city: filter.location,
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
          (results[i] as List<dynamic>)
              .map((e) => _PropertyResult(PropertyModel.fromJson(e)))
              .toList(), // Removed unnecessary cast: 'e as Map<String, dynamic>'
        );
      case 'agriculture':
        combined.addAll(
          (results[i] as List<dynamic>)
              .map((e) => _AgriResult(AgricultureListingModel.fromJson(e)))
              .toList(), // Removed unnecessary cast: 'e as Map<String, dynamic>'
        );
      case 'manufacturing':
        combined.addAll(
          (results[i] as List<dynamic>)
              .map((e) => _MfgResult(ManufacturingProductModel.fromJson(e)))
              .toList(), // Removed unnecessary cast: 'e as Map<String, dynamic>'
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
                ? const Center(
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
                  )
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
            price: '\$${item.price.toStringAsFixed(0)}',
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
                '\$${item.pricePerUnit.toStringAsFixed(2)}/${item.unit ?? 'unit'}',
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
                '\$${item.wholesalePrice.toStringAsFixed(2)}/${item.unit ?? 'unit'}',
            imageUrl: (item.images?.isNotEmpty == true)
                ? item.images!.first
                : null,
            onTap: () => ctx.go('/manufacturing/${item.id}'),
          ),
      };
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

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _minPriceCtrl.text = c.minPrice?.toStringAsFixed(0) ?? '';
    _maxPriceCtrl.text = c.maxPrice?.toStringAsFixed(0) ?? '';
    _locationCtrl.text = c.location ?? '';
    _categoryCtrl.text = c.category ?? '';
    _section = c.section ?? 'all';
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
