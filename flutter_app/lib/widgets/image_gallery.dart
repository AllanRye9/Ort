import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A horizontally-scrollable image gallery with optional full-screen view.
/// If [imageUrls] is empty or null, a gradient placeholder with [placeholderIcon]
/// is shown instead.
class ImageGallery extends StatefulWidget {
  const ImageGallery({
    super.key,
    required this.imageUrls,
    this.height = 240,
    this.placeholderIcon,
    this.placeholderColor,
    this.borderRadius = 0,
  });

  final List<String>? imageUrls;
  final double height;
  final IconData? placeholderIcon;
  final Color? placeholderColor;
  final double borderRadius;

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  int _current = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _hasImages =>
      widget.imageUrls != null && widget.imageUrls!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final color = widget.placeholderColor ??
        Theme.of(context).colorScheme.primaryContainer;

    if (!_hasImages) {
      return _Placeholder(
        height: widget.height,
        color: color,
        icon: widget.placeholderIcon ?? Icons.image_outlined,
        borderRadius: widget.borderRadius,
      );
    }

    final urls = widget.imageUrls!;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: PageView.builder(
              controller: _pageController,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () => _openFullScreen(ctx, urls, i),
                child: CachedNetworkImage(
                  imageUrl: urls[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Shimmer.fromColors(
                    baseColor: color,
                    highlightColor:
                        Theme.of(ctx).colorScheme.surfaceVariant,
                    child: Container(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => _Placeholder(
                    height: widget.height,
                    color: color,
                    icon: widget.placeholderIcon ?? Icons.broken_image_outlined,
                    borderRadius: 0,
                  ),
                ),
              ),
            ),
          ),

          // Page indicator dots
          if (urls.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  urls.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _current ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _current
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),

          // Image count badge
          if (urls.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_current + 1} / ${urls.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFullScreen(
      BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            _FullScreenGallery(urls: urls, initialIndex: initialIndex),
      ),
    );
  }
}

// ─── Placeholder ─────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.height,
    required this.color,
    required this.icon,
    required this.borderRadius,
  });

  final double height;
  final Color color;
  final IconData icon;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: height * 0.3,
              color: color == Colors.white
                  ? Colors.grey[400]
                  : color.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
}

// ─── Full-screen gallery ──────────────────────────────────────────────────────

class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery(
      {required this.urls, required this.initialIndex});
  final List<String> urls;
  final int initialIndex;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late int _current;
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(
            '${_current + 1} / ${widget.urls.length}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: PageView.builder(
          controller: _ctrl,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (ctx, i) => InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.urls[i],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),
          ),
        ),
      );
}
