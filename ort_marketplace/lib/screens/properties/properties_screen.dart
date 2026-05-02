import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/listing_providers.dart';
import '../../core/location_service.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../widgets/listing_card.dart';

class PropertiesScreen extends ConsumerStatefulWidget {
  const PropertiesScreen({super.key});

  @override
  ConsumerState<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends ConsumerState<PropertiesScreen> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';
  String? _propertyType;
  String? _status;
  double? _minPrice;
  double? _maxPrice;
  double? _radiusKm;
  double? _lat;
  double? _lon;
  bool _locationLoading = false;

  List<PropertyModel>? _items;
  bool _loading = true;
  String? _error;

  static const _propertyTypes = [
    'house', 'apartment', 'land', 'commercial', 'villa', 'office',
    'warehouse', 'other',
  ];
  static const _statuses = ['available', 'sold', 'rented', 'pending'];

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(apiServiceProvider).getPropertiesFiltered(
            keyword: _keyword.isNotEmpty ? _keyword : null,
            propertyType: _propertyType,
            status: _status,
            minPrice: _minPrice,
            maxPrice: _maxPrice,
            lat: _lat,
            lon: _lon,
            radiusKm: _radiusKm,
          );
      if (mounted) {
        setState(() {
          _items = data
              .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
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

  Future<void> _confirmDeleteProperty(PropertyModel p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text('Delete "${p.title}"? This cannot be undone.'),
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
      await ref.read(apiServiceProvider).deleteProperty(p.id);
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
      _propertyType = null;
      _status = null;
      _minPrice = null;
      _maxPrice = null;
      _radiusKm = null;
      _lat = null;
      _lon = null;
      _searchCtrl.clear();
    });
    _loadListings();
  }

  bool get _hasActiveFilters =>
      _keyword.isNotEmpty ||
      _propertyType != null ||
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
    String? tempType = _propertyType;
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
                Text('Filter Properties',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 16),
                Text('Property Type',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600])),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _propertyTypes
                      .map((t) => ChoiceChip(
                            label: Text(t, style: const TextStyle(fontSize: 12)),
                            selected: tempType == t,
                            onSelected: (v) =>
                                setModal(() => tempType = v ? t : null),
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
                            onSelected: (v) =>
                                setModal(() => tempStatus = v ? s : null),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text('Price Range',
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
                          labelText: 'Min Price',
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
                          labelText: 'Max Price',
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
                            _propertyType = tempType;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Properties'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              tooltip: 'Clear Filters',
              onPressed: _clearFilters,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('List Property'),
        onPressed: () => context.go('/properties/create'),
      ),
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
                        hintText: 'Search properties…',
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
          if (_propertyType != null || _status != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
              child: SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (_propertyType != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text(_propertyType!,
                              style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () {
                            setState(() => _propertyType = null);
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
            child: SizedBox(
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
                  for (final km in [1.0, 5.0, 10.0, 20.0, 30.0, 40.0, 50.0])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('${km.toInt()} km',
                            style: const TextStyle(fontSize: 12)),
                        selected: _radiusKm == km,
                        onSelected: (_) => _toggleRadius(km),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
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
                                Icon(Icons.apartment_outlined,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  _hasActiveFilters
                                      ? 'No properties match your filters.'
                                      : 'No properties listed yet.',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 16),
                                if (!_hasActiveFilters)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add First Listing'),
                                    onPressed: () =>
                                        context.go('/properties/create'),
                                  )
                                else
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
                              builder: (ctx, constraints) {
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
                                    final p = _items![i];
                                    return ListingCard(
                                      icon: Icons.apartment_rounded,
                                      iconColor:
                                          Theme.of(ctx).colorScheme.primary,
                                      imageUrl: p.imageUrls.isNotEmpty
                                          ? p.imageUrls.first
                                          : null,
                                      title: p.title,
                                      subtitle: p.city ?? p.address,
                                      tag: p.propertyType,
                                      status: p.status,
                                      price:
                                          '\$${p.price.toStringAsFixed(0)}',
                                      extras: [
                                        if (p.propertyType == 'land' && p.landCategory != null)
                                          '${p.landCategory![0].toUpperCase()}${p.landCategory!.substring(1)} Land',
                                        if (p.propertyType == 'land' && p.landAreaAcres != null)
                                          '${p.landAreaAcres!.toStringAsFixed(2)} acres',
                                        if (p.bedrooms != null)
                                          '${p.bedrooms} Bedroom${p.bedrooms! != 1 ? 's' : ''}',
                                        if (p.bathrooms != null)
                                          '${p.bathrooms} Bathroom${p.bathrooms! != 1 ? 's' : ''}',
                                        if (p.areaSqft != null)
                                          '${p.areaSqft} sq ft',
                                      ],
                                      onTap: () =>
                                          ctx.go('/properties/${p.id}'),
                                      onLongPress: () =>
                                          _confirmDeleteProperty(p),
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
