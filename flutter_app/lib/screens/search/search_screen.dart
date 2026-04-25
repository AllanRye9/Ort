import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';
import '../../widgets/listing_card.dart';

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

// ─── Search provider ──────────────────────────────────────────────────────────

/// The query only updates when the user explicitly submits (Enter / search
/// button), preventing a network round-trip on every keystroke.
final _searchQueryProvider = StateProvider<String>((ref) => '');

final _searchResultsProvider =
    FutureProvider.autoDispose<List<_SearchResult>>((ref) async {
  // Only watch the submitted query so we don't fetch on every keystroke.
  final query = ref.watch(_searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return const [];

  final api = ref.read(apiServiceProvider);

  final results = await Future.wait([
    api.getProperties(limit: 100),
    api.getAgricultureListings(limit: 100),
    api.getManufacturingProducts(limit: 100),
  ]);

  final properties = (results[0] as List<dynamic>)
      .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
      .where((p) =>
          p.title.toLowerCase().contains(query) ||
          (p.city?.toLowerCase().contains(query) ?? false) ||
          p.address.toLowerCase().contains(query))
      .map((p) => _PropertyResult(p) as _SearchResult)
      .toList();

  final agri = (results[1] as List<dynamic>)
      .map((e) =>
          AgricultureListingModel.fromJson(e as Map<String, dynamic>))
      .where((a) =>
          a.title.toLowerCase().contains(query) ||
          (a.category?.toLowerCase().contains(query) ?? false) ||
          (a.location?.toLowerCase().contains(query) ?? false))
      .map((a) => _AgriResult(a) as _SearchResult)
      .toList();

  final mfg = (results[2] as List<dynamic>)
      .map((e) =>
          ManufacturingProductModel.fromJson(e as Map<String, dynamic>))
      .where((m) =>
          m.title.toLowerCase().contains(query) ||
          (m.category?.toLowerCase().contains(query) ?? false))
      .map((m) => _MfgResult(m) as _SearchResult)
      .toList();

  return [...properties, ...agri, ...mfg];
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
    ref.read(_searchQueryProvider.notifier).state = text;
  }

  @override
  Widget build(BuildContext context) {
    final submittedQuery = ref.watch(_searchQueryProvider);
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
            prefixIcon: Icon(Icons.search,
                color: Colors.white.withValues(alpha: 0.7)),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _ctrl.clear();
                      ref.read(_searchQueryProvider.notifier).state = '';
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
        ],
      ),
      body: submittedQuery.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Type a search term and press Enter…',
                      style: TextStyle(color: Colors.grey)),
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
                        Text('No results for "$submittedQuery"',
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final r = items[i];
                    return switch (r) {
                      _PropertyResult(:final item) => ListingCard(
                          icon: Icons.home,
                          iconColor: Theme.of(ctx).colorScheme.primary,
                          title: item.title,
                          subtitle: item.city ?? item.address,
                          tag: item.propertyType,
                          status: item.status,
                          price: '\$${item.price.toStringAsFixed(0)}',
                          extras: [
                            if (item.bedrooms != null)
                              '${item.bedrooms} bd',
                            if (item.bathrooms != null)
                              '${item.bathrooms} ba',
                          ],
                          onTap: () => ctx.go('/properties/${item.id}'),
                        ),
                      _AgriResult(:final item) => ListingCard(
                          icon: Icons.grass,
                          iconColor: Colors.green,
                          title: item.title,
                          subtitle:
                              item.location ?? item.commodityType ?? '',
                          tag: item.category ?? 'Agriculture',
                          status: item.status,
                          price:
                              '\$${item.pricePerUnit.toStringAsFixed(2)}/${item.unit ?? 'unit'}',
                          onTap: () =>
                              ctx.go('/agriculture/${item.id}'),
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
                          onTap: () =>
                              ctx.go('/manufacturing/${item.id}'),
                        ),
                    };
                  },
                );
              },
            ),
    );
  }
}
