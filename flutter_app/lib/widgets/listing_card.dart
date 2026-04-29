import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A generic listing card used across property, agriculture and manufacturing
/// list screens.  Supports an optional [imageUrl] that renders as a hero image
/// at the top of the card; when absent a gradient placeholder is shown.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.status,
    required this.price,
    this.extras = const [],
    this.imageUrl,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String tag;
  final String status;
  final String price;
  final List<String> extras;
  final String? imageUrl;
  final VoidCallback onTap;

  Color _statusColor(String s) {
    switch (s) {
      case 'available':
        return const Color(0xFF2E7D32);
      case 'sold':
      case 'sold_out':
      case 'out_of_stock':
      case 'discontinued':
        return Colors.red[700]!;
      case 'reserved':
      case 'pending':
        return Colors.orange[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero image / placeholder ───────────────────────────────────
            _HeroImage(
              imageUrl: imageUrl,
              icon: icon,
              iconColor: iconColor,
              status: status,
              statusColor: _statusColor(status),
            ),

            // ── Text content ───────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _TagChip(label: tag, color: iconColor),
                        const Spacer(),
                        Text(
                          price,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (extras.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        extras.where((e) => e.trim().isNotEmpty).join(' · '),
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero image ───────────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.imageUrl,
    required this.icon,
    required this.iconColor,
    required this.status,
    required this.statusColor,
  });

  final String? imageUrl;
  final IconData icon;
  final Color iconColor;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    const height = 120.0;

    final badge = Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: statusColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
        ),
      ),
    );

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Stack(
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Shimmer.fromColors(
              baseColor: Colors.grey[200]!,
              highlightColor: Colors.grey[100]!,
              child: Container(height: height, color: Colors.white),
            ),
            errorWidget: (_, __, ___) => _Placeholder(
              height: height,
              icon: icon,
              iconColor: iconColor,
            ),
          ),
          badge,
        ],
      );
    }

    return Stack(
      children: [
        _Placeholder(height: height, icon: icon, iconColor: iconColor),
        badge,
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.height,
    required this.icon,
    required this.iconColor,
  });

  final double height;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: double.infinity,
        color: iconColor.withValues(alpha: 0.08),
        child: Center(
          child: Icon(icon, size: height * 0.3, color: iconColor.withValues(alpha: 0.4)),
        ),
      );
}

// ─── Tag chip ─────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );
}
