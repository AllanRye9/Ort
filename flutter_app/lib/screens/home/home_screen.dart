import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';

final _propertiesProvider = FutureProvider.autoDispose<List<PropertyModel>>(
  (ref) async {
    final api = ref.read(apiServiceProvider);
    final data = await api.getProperties(limit: 20);
    return data
        .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final _agricultureProvider =
    FutureProvider.autoDispose<List<AgricultureListingModel>>(
  (ref) async {
    final api = ref.read(apiServiceProvider);
    final data = await api.getAgricultureListings(limit: 6);
    return data
        .map((e) =>
            AgricultureListingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final _mfgProvider =
    FutureProvider.autoDispose<List<ManufacturingProductModel>>(
  (ref) async {
    final api = ref.read(apiServiceProvider);
    final data = await api.getManufacturingProducts(limit: 6);
    return data
        .map((e) =>
            ManufacturingProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(_propertiesProvider);
    final agricultureAsync = ref.watch(_agricultureProvider);
    final mfgAsync = ref.watch(_mfgProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ort Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_propertiesProvider);
          ref.invalidate(_agricultureProvider);
          ref.invalidate(_mfgProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SearchBar(),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Properties',
              onSeeAll: () => context.go('/properties'),
            ),
            const SizedBox(height: 12),
            propertiesAsync.when(
              loading: () => _HorizontalShimmer(),
              error: (e, _) => _ErrorTile(message: e.toString()),
              data: (items) => _PropertyRow(items: items),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Agriculture',
              onSeeAll: () => context.go('/agriculture'),
            ),
            const SizedBox(height: 12),
            agricultureAsync.when(
              loading: () => _HorizontalShimmer(),
              error: (e, _) => _ErrorTile(message: e.toString()),
              data: (items) => _AgriRow(items: items),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Manufacturing',
              onSeeAll: () => context.go('/manufacturing'),
            ),
            const SizedBox(height: 12),
            mfgAsync.when(
              loading: () => _HorizontalShimmer(),
              error: (e, _) => _ErrorTile(message: e.toString()),
              data: (items) => _MfgRow(items: items),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({super.key});
  @override
  Widget build(BuildContext context) {
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Search properties, agri, goods…',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

class _HorizontalShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 180,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Failed to load'),
        subtitle: Text(message, maxLines: 1),
      );
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.items});
  final List<PropertyModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('No properties listed yet.');
    }
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final p = items[i];
          return GestureDetector(
            onTap: () => ctx.go('/properties/${p.id}'),
            child: SizedBox(
              width: 200,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.home,
                        color: Theme.of(ctx).colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        p.city ?? p.address,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '\$${p.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
    if (items.isEmpty) return const Text('No agriculture listings yet.');
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final a = items[i];
          return GestureDetector(
            onTap: () => ctx.go('/agriculture/${a.id}'),
            child: SizedBox(
              width: 180,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.grass, color: Colors.green, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        '\$${a.pricePerUnit.toStringAsFixed(2)}/${a.unit ?? 'unit'}',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
    if (items.isEmpty) return const Text('No manufacturing products yet.');
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final m = items[i];
          return GestureDetector(
            onTap: () => ctx.go('/manufacturing/${m.id}'),
            child: SizedBox(
              width: 180,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.factory, color: Colors.orange, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        m.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        '\$${m.wholesalePrice.toStringAsFixed(2)}/${m.unit ?? 'unit'}',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
