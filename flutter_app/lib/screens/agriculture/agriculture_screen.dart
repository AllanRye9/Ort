import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
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
    super.dispose();
  }

  Future<void> _loadListings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(apiServiceProvider).getAgricultureFiltered(
            keyword: _keyword.isNotEmpty ? _keyword : null,
            category: _category,
            status: _status,
            minPrice: _minPrice,
            maxPrice: _maxPrice,
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
      _searchCtrl.clear();
    });
    _loadListings();
  }

  bool get _hasActiveFilters =>
      _keyword.isNotEmpty ||
      _category != null ||
      _status != null ||
      _minPrice != null ||
      _maxPrice != null;

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
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Listing'),
        onPressed: () => context.go('/agriculture/create'),
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
                                if (!_hasActiveFilters)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add First Listing'),
                                    onPressed: () =>
                                        context.go('/agriculture/create'),
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
                                    childAspectRatio: 0.7,
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
                                          '\$${a.pricePerUnit.toStringAsFixed(2)}/${a.unit ?? 'unit'}',
                                      extras: [
                                        if (a.qualityGrade != null)
                                          a.qualityGrade!,
                                        if (a.moq != null) 'MOQ: ${a.moq}',
                                        if (a.isPerishable) '⚠ Perishable',
                                      ],
                                      onTap: () =>
                                          ctx.go('/agriculture/${a.id}'),
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
