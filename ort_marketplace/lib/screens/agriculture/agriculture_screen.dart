import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/app_preferences.dart';
import '../../core/auth_provider.dart';
import '../../core/listing_providers.dart';
import '../../core/location_service.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../widgets/listing_card.dart';

class AgricultureScreen extends ConsumerStatefulWidget {
  const AgricultureScreen({super.key});

  @override
  ConsumerState<AgricultureScreen> createState() => _AgricultureScreenState();
}

class _AgricultureScreenState extends ConsumerState<AgricultureScreen> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';
  String? _category;
  String? _status;
  double? _minPrice;
  double? _maxPrice;
  double? _radiusKm;
  double? _lat;
  double? _lon;
  bool _locationLoading = false;
  bool _showCustomRadius = false;
  final _customRadiusCtrl = TextEditingController();

  MarketplaceMode? _lastMode;
  String? _lastUserCountry;
  String? _lastIntlFilter;
  bool _reloadPending = false;

  List<AgricultureListingModel>? _items;
  bool _loading = true;
  String? _error;

  static const _categories = [
    'grains', 'vegetables', 'fruits', 'livestock', 'dairy',
    'poultry', 'fish', 'spices', 'oils', 'other',
  ];
  static const _statuses = ['available', 'sold_out', 'reserved'];

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customRadiusCtrl.dispose();
    super.dispose();
  }

  ({String? country, String? excludeCountry}) _countryFilter() {
    final mode = ref.read(marketplaceModeProvider);
    final userCountry = ref.read(userCountryProvider);
    final intlFilter = ref.read(intlCountryFilterProvider);
    if (mode == MarketplaceMode.local) {
      return (country: userCountry, excludeCountry: null);
    } else {
      if (intlFilter.isNotEmpty) {
        return (country: intlFilter, excludeCountry: null);
      }
      return (country: null, excludeCountry: userCountry);
    }
  }

  Future<void> _loadListings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (:country, :excludeCountry) = _countryFilter();
      final data = await ref.read(apiServiceProvider).getAgricultureFiltered(
            keyword: _keyword.isNotEmpty ? _keyword : null,
            category: _category,
            status: _status,
            minPrice: _minPrice,
            maxPrice: _maxPrice,
            lat: _lat,
            lon: _lon,
            radiusKm: _radiusKm,
            country: country,
            excludeCountry: excludeCountry,
          );
      if (mounted) {
        setState(() {
          _items = data
              .map((e) =>
                  AgricultureListingModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteAgriculture(AgricultureListingModel a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text('Delete "${a.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(apiServiceProvider).deleteAgricultureListing(a.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadListings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _applySearch() {
    setState(() => _keyword = _searchCtrl.text.trim());
    _loadListings();
  }

  void _clearFilters() {
    setState(() {
      _keyword = '';
      _category = null;
      _status = null;
      _minPrice = null;
      _maxPrice = null;
      _radiusKm = null;
      _lat = null;
      _lon = null;
      _showCustomRadius = false;
      _searchCtrl.clear();
      _customRadiusCtrl.clear();
    });
    _loadListings();
  }

  bool get _hasActiveFilters =>
      _keyword.isNotEmpty ||
      _category != null ||
      _status != null ||
      _minPrice != null ||
      _maxPrice != null ||
      _radiusKm != null;

  Future<void> _toggleRadius(double km) async {
    if (_radiusKm == km) {
      setState(() {
        _radiusKm = null;
        _lat = null;
        _lon = null;
      });
      _loadListings();
      return;
    }
    setState(() => _locationLoading = true);
    // Use cached location from shared provider when available.
    final cached = ref.read(userLocationProvider);
    if (cached != null) {
      setState(() {
        _lat = cached.$1;
        _lon = cached.$2;
        _radiusKm = km;
        _locationLoading = false;
      });
      _loadListings();
      return;
    }
    final pos = await LocationService.instance.requestAndGetPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() => _locationLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enable GPS to search by distance.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () async {
              try {
                await Geolocator.openAppSettings();
              } catch (_) {}
            },
          ),
        ),
      );
      return;
    }
    // Cache the position for reuse.
    ref.read(userLocationProvider.notifier).state =
        (pos.latitude, pos.longitude);
    setState(() {
      _lat = pos.latitude;
      _lon = pos.longitude;
      _radiusKm = km;
      _locationLoading = false;
    });
    _loadListings();
  }

  void _showFilterSheet() {
    String? tempCat = _category;
    String? tempStatus = _status;
    final minCtrl =
        TextEditingController(text: _minPrice?.toStringAsFixed(0) ?? '');
    final maxCtrl =
        TextEditingController(text: _maxPrice?.toStringAsFixed(0) ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Filter Agriculture',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 16),
                Text('Category',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600])),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _categories
                      .map((c) => ChoiceChip(
                            label: Text(c, style: const TextStyle(fontSize: 12)),
                            selected: tempCat == c,
                            selectedColor:
                                const Color(0xFF388E3C).withValues(alpha: 0.2),
                            onSelected: (v) =>
                                setModal(() => tempCat = v ? c : null),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text('Status',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600])),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _statuses
                      .map((s) => ChoiceChip(
                            label: Text(s, style: const TextStyle(fontSize: 12)),
                            selected: tempStatus == s,
                            selectedColor:
                                const Color(0xFF388E3C).withValues(alpha: 0.2),
                            onSelected: (v) =>
                                setModal(() => tempStatus = v ? s : null),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text('Price Range (per unit)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min',
                          prefixText: '\$',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max',
                          prefixText: '\$',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _category = tempCat;
                            _status = tempStatus;
                            _minPrice = minCtrl.text.isNotEmpty
                                ? double.tryParse(minCtrl.text)
                                : null;
                            _maxPrice = maxCtrl.text.isNotEmpty
                                ? double.tryParse(maxCtrl.text)
                                : null;
                          });
                          _loadListings();
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canList = auth.role != 'user';
    final mode = ref.watch(marketplaceModeProvider);
    final userCountry = ref.watch(userCountryProvider);
    final intlFilter = ref.watch(intlCountryFilterProvider);
    if (_lastMode != null &&
        !_reloadPending &&
        (_lastMode != mode ||
            _lastUserCountry != userCountry ||
            _lastIntlFilter != intlFilter)) {
      _reloadPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reloadPending = false;
          _loadListings();
        }
      });
    }
    _lastMode = mode;
    _lastUserCountry = userCountry;
    _lastIntlFilter = intlFilter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agriculture Listings'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              tooltip: 'Clear Filters',
              onPressed: _clearFilters,
            ),
        ],
      ),
      floatingActionButton: canList
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add Listing'),
              onPressed: () => context.go('/agriculture/create'),
            )
          : null,
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (context, value, _) => TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search agriculture listings…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _applySearch();
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onSubmitted: (_) => _applySearch(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _hasActiveFilters,
                  child: IconButton.outlined(
                    icon: const Icon(Icons.tune, size: 20),
                    tooltip: 'Filters',
                    onPressed: _showFilterSheet,
                  ),
                ),
              ],
            ),
          ),
          // ── Active filter chips ────────────────────────────────────
          if (_category != null || _status != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
              child: SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (_category != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text(_category!,
                              style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () {
                            setState(() => _category = null);
                            _loadListings();
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    if (_status != null)
                      Chip(
                        label: Text(_status!,
                            style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() => _status = null);
                          _loadListings();
                        },
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ),
          // ── Radius filter chips ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _locationLoading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              )
                            : const Icon(Icons.my_location_outlined,
                                size: 16, color: Colors.grey),
                      ),
                      for (final km in [1.0, 5.0, 10.0, 20.0, 50.0])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text('${km.toInt()} km',
                                style: const TextStyle(fontSize: 12)),
                            selected: _radiusKm == km && !_showCustomRadius,
                            onSelected: (_) {
                              setState(() => _showCustomRadius = false);
                              _toggleRadius(km);
                            },
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      FilterChip(
                        label: const Text('Custom',
                            style: TextStyle(fontSize: 12)),
                        selected: _showCustomRadius,
                        onSelected: (_) =>
                            setState(() => _showCustomRadius = !_showCustomRadius),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                if (_showCustomRadius) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _customRadiusCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            hintText: 'e.g. 35',
                            suffixText: 'km',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onSubmitted: (v) {
                            final km = double.tryParse(v);
                            if (km != null && km > 0) _toggleRadius(km);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final km =
                              double.tryParse(_customRadiusCtrl.text);
                          if (km != null && km > 0) _toggleRadius(km);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Go'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // ── Results ───────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Error: $_error'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadListings,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _items == null || _items!.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.grass_outlined,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  _hasActiveFilters
                                      ? 'No listings match your filters.'
                                      : 'No agriculture listings yet.',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 16),
                                if (!_hasActiveFilters && canList)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add First Listing'),
                                    onPressed: () =>
                                        context.go('/agriculture/create'),
                                  )
                                else if (_hasActiveFilters)
                                  TextButton(
                                    onPressed: _clearFilters,
                                    child: const Text('Clear Filters'),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadListings,
                            child: LayoutBuilder(
                              builder: (ctx, _) {
                                final cols = ctx.gridColumns;
                                return GridView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    ctx.contentPadding.left,
                                    4,
                                    ctx.contentPadding.right,
                                    80,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    childAspectRatio: 0.65,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: _items!.length,
                                  itemBuilder: (ctx, i) {
                                    final a = _items![i];
                                    final imgUrl = (a.images != null &&
                                            a.images!.isNotEmpty)
                                        ? a.images!.first
                                        : null;
                                    return ListingCard(
                                      icon: Icons.grass_rounded,
                                      iconColor: const Color(0xFF388E3C),
                                      imageUrl: imgUrl,
                                      title: a.title,
                                      subtitle:
                                          a.location ?? a.commodityType ?? '',
                                      tag: a.category ?? 'Agriculture',
                                      status: a.status,
                                      price:
                                          '${formatCurrencyForMode(a.pricePerUnit, currency: a.currency, decimals: 2, mode: mode)}/${a.unit ?? 'unit'}',
                                      extras: [
                                        if (a.qualityGrade != null)
                                          a.qualityGrade!,
                                        if (a.moq != null) 'MOQ: ${a.moq}',
                                        if (a.isPerishable) '⚠ Perishable',
                                      ],
                                      onTap: () =>
                                          ctx.go('/agriculture/${a.id}'),
                                      onLongPress: () =>
                                          _confirmDeleteAgriculture(a),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
