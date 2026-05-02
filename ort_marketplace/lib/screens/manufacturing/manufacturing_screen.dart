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

class ManufacturingScreen extends ConsumerStatefulWidget {
  const ManufacturingScreen({super.key});

  @override
  ConsumerState<ManufacturingScreen> createState() =>
      _ManufacturingScreenState();
}

class _ManufacturingScreenState extends ConsumerState<ManufacturingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ── Products state ─────────────────────────────────────────────────────────
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

  List<ManufacturingProductModel>? _items;
  bool _loading = true;
  String? _error;

  // ── Services state ─────────────────────────────────────────────────────────
  final _svcSearchCtrl = TextEditingController();
  String _svcKeyword = '';
  String? _svcType;
  String? _svcStatus;

  List<ManufacturingServiceModel>? _svcItems;
  bool _svcLoading = true;
  String? _svcError;

  static const _categories = [
    'textiles', 'electronics', 'furniture', 'food_processing',
    'packaging', 'chemicals', 'automotive', 'construction', 'other',
  ];
  static const _statuses = ['available', 'out_of_stock', 'discontinued'];

  static const _serviceTypes = [
    'machining', 'fabrication', 'welding', 'assembly',
    'finishing', 'testing', 'printing', 'packaging',
    'consultation', 'other',
  ];
  static const _serviceStatuses = ['available', 'fully_booked', 'discontinued'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadListings();
    _loadServices();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _customRadiusCtrl.dispose();
    _svcSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(apiServiceProvider).getManufacturingFiltered(
            keyword: _keyword.isNotEmpty ? _keyword : null,
            category: _category,
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
              .map((e) =>
                  ManufacturingProductModel.fromJson(e as Map<String, dynamic>))
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

  Future<void> _confirmDeleteManufacturing(ManufacturingProductModel m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${m.title}"? This cannot be undone.'),
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
      await ref.read(apiServiceProvider).deleteManufacturingProduct(m.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted.'),
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

  // ── Services methods ───────────────────────────────────────────────────────

  Future<void> _loadServices() async {
    setState(() {
      _svcLoading = true;
      _svcError = null;
    });
    try {
      final data = await ref.read(apiServiceProvider).getManufacturingServices(
            keyword: _svcKeyword.isNotEmpty ? _svcKeyword : null,
            serviceType: _svcType,
            status: _svcStatus,
          );
      if (mounted) {
        setState(() {
          _svcItems = data
              .map((e) => ManufacturingServiceModel.fromJson(
                  e as Map<String, dynamic>))
              .toList();
          _svcLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _svcError = e.toString();
          _svcLoading = false;
        });
      }
    }
  }

  void _applySvcSearch() {
    setState(() => _svcKeyword = _svcSearchCtrl.text.trim());
    _loadServices();
  }

  Future<void> _confirmDeleteService(ManufacturingServiceModel s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Delete "${s.title}"? This cannot be undone.'),
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
      await ref.read(apiServiceProvider).deleteManufacturingService(s.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadServices();
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
                Text('Filter Manufacturing',
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
                                const Color(0xFFE65100).withValues(alpha: 0.15),
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
                                const Color(0xFFE65100).withValues(alpha: 0.15),
                            onSelected: (v) =>
                                setModal(() => tempStatus = v ? s : null),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text('Wholesale Price Range',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manufacturing & Services'),
        actions: [
          if (_tabCtrl.index == 0 && _hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              tooltip: 'Clear Filters',
              onPressed: _clearFilters,
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Products'),
            Tab(icon: Icon(Icons.build_outlined), text: 'Services'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Listing'),
        onPressed: () => context.go('/manufacturing/create'),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildProductsTab(context),
          _buildServicesTab(context),
        ],
      ),
    );
  }

  Widget _buildProductsTab(BuildContext context) {
    return Column(
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
                        hintText: 'Search products…',
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
                                Icon(Icons.precision_manufacturing_outlined,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  _hasActiveFilters
                                      ? 'No products match your filters.'
                                      : 'No products listed yet.',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 16),
                                if (!_hasActiveFilters)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add First Product'),
                                    onPressed: () =>
                                        context.go('/manufacturing/create'),
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
                                    final m = _items![i];
                                    final imgUrl = (m.images != null &&
                                            m.images!.isNotEmpty)
                                        ? m.images!.first
                                        : null;
                                    return ListingCard(
                                      icon: Icons.precision_manufacturing_rounded,
                                      iconColor: const Color(0xFFE65100),
                                      imageUrl: imgUrl,
                                      title: m.title,
                                      subtitle: m.location ??
                                          m.category ??
                                          (m.isLocallyMade ? 'Locally Made' : ''),
                                      tag: m.category ?? 'Manufacturing',
                                      status: m.status,
                                      price:
                                          '\$${m.wholesalePrice.toStringAsFixed(2)}/${m.unit ?? 'unit'}',
                                      extras: [
                                        if (m.moq != null) 'Min order: ${m.moq}',
                                        if (m.leadTimeDays != null)
                                          '${m.leadTimeDays} day lead time',
                                        if (m.isLocallyMade) 'Locally made',
                                      ],
                                      onTap: () =>
                                          ctx.go('/manufacturing/${m.id}'),
                                      onDoubleTap: () =>
                                          _confirmDeleteManufacturing(m),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      );
  }

  Widget _buildServicesTab(BuildContext context) {
    return Column(
      children: [
        // ── Search bar ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _svcSearchCtrl,
            builder: (context, value, _) => TextField(
              controller: _svcSearchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search services…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _svcSearchCtrl.clear();
                          _applySvcSearch();
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (_) => _applySvcSearch(),
            ),
          ),
        ),
        // ── Service type filter chips ──────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _serviceTypes
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(
                            t[0].toUpperCase() + t.substring(1),
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _svcType == t,
                          onSelected: (v) {
                            setState(() => _svcType = v ? t : null);
                            _loadServices();
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        // ── Results ───────────────────────────────────────────────
        Expanded(
          child: _svcLoading
              ? const Center(child: CircularProgressIndicator())
              : _svcError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Error: $_svcError'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadServices,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _svcItems == null || _svcItems!.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.build_outlined,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No services listed yet.',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Service'),
                                onPressed: () =>
                                    context.go('/manufacturing/create'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadServices,
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
                                itemCount: _svcItems!.length,
                                itemBuilder: (ctx, i) {
                                  final s = _svcItems![i];
                                  final imgUrl = (s.images != null &&
                                          s.images!.isNotEmpty)
                                      ? s.images!.first
                                      : null;
                                  final pricingLabel = s.pricingUnit != null
                                      ? s.pricingUnit!.replaceAll('_', ' ')
                                      : 'flat rate';
                                  return ListingCard(
                                    icon: Icons.build_rounded,
                                    iconColor: const Color(0xFF1565C0),
                                    imageUrl: imgUrl,
                                    title: s.title,
                                    subtitle:
                                        s.location ?? s.serviceType ?? 'Service',
                                    tag: s.serviceType != null
                                        ? s.serviceType![0].toUpperCase() +
                                            s.serviceType!.substring(1)
                                        : 'Service',
                                    status: s.status,
                                    price:
                                        '\$${s.price.toStringAsFixed(2)} / $pricingLabel',
                                    extras: [
                                      if (s.noticePeriodDays != null)
                                        '${s.noticePeriodDays} day notice',
                                    ],
                                    onTap: () => ctx
                                        .go('/manufacturing/service/${s.id}'),
                                    onDoubleTap: () =>
                                        _confirmDeleteService(s),
                                  );
                                },
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

