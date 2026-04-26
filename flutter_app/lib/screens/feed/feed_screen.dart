import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import '../../core/api_service.dart';
import '../../widgets/skeleton_loader.dart';

final _feedProvider = StateNotifierProvider.autoDispose<_FeedNotifier, _FeedState>(
  (ref) => _FeedNotifier(ref.read(apiServiceProvider)),
);

class _FeedState {
  const _FeedState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.cursor,
    this.error,
  });

  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool hasMore;
  final String? cursor;
  final String? error;

  _FeedState copyWith({
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    bool? hasMore,
    String? cursor,
    String? error,
    bool clearError = false,
  }) =>
      _FeedState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        cursor: cursor ?? this.cursor,
        error: clearError ? null : error ?? this.error,
      );
}

class _FeedNotifier extends StateNotifier<_FeedState> {
  _FeedNotifier(this._api) : super(const _FeedState()) {
    loadMore();
  }

  final ApiService _api;

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.getFeed(after: state.cursor);
      final newItems = (result['items'] as List)
          .cast<Map<String, dynamic>>();
      final nextCursor = result['next_cursor'] as String?;
      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoading: false,
        hasMore: newItems.isNotEmpty && nextCursor != null,
        cursor: nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void refresh() {
    state = const _FeedState();
    loadMore();
  }
}

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(_feedProvider.notifier).loadMore();
    }
  }

  void _showLightbox(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoView(imageProvider: CachedNetworkImageProvider(imageUrl)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(_feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(_feedProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(_feedProvider.notifier).refresh(),
        child: feedState.items.isEmpty && feedState.isLoading
            ? ListView.builder(
                itemCount: 5,
                itemBuilder: (_, __) => const FeedCardSkeleton(),
              )
            : ListView.builder(
                controller: _scrollController,
                itemCount: feedState.items.length + (feedState.hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == feedState.items.length) {
                    return feedState.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }
                  final item = feedState.items[i];
                  return _FeedCard(
                    item: item,
                    onImageTap: (url) => _showLightbox(context, url),
                  );
                },
              ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item, required this.onImageTap});

  final Map<String, dynamic> item;
  final void Function(String url) onImageTap;

  IconData get _typeIcon {
    switch (item['type'] as String? ?? '') {
      case 'property':
        return Icons.apartment_outlined;
      case 'agriculture':
        return Icons.grass_outlined;
      case 'manufacturing':
        return Icons.precision_manufacturing_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = item['image_url'] as String?;
    final title = item['title'] as String? ?? '';
    final type = item['type'] as String? ?? '';
    final price = item['price'];
    final status = item['status'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            GestureDetector(
              onTap: () => onImageTap(imageUrl),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SkeletonBox(
                  width: double.infinity,
                  height: 160,
                  borderRadius: 0,
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 160,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, size: 48),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(_typeIcon, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  type.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (price != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                '\$${price.toString()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
