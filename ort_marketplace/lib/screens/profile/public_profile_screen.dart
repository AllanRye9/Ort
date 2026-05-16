import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _pubUserProvider =
    FutureProvider.autoDispose.family<UserModel, int>((ref, id) async {
  final data = await ref.read(apiServiceProvider).getUser(id);
  return UserModel.fromJson(data);
});

final _pubStatsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
        (ref, id) async => ref.read(apiServiceProvider).getAgentStats(id));

final _pubReviewsProvider =
    FutureProvider.autoDispose.family<List<ReviewModel>, int>((ref, id) async {
  final data = await ref.read(apiServiceProvider).getAgentReviews(id);
  return data
      .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_pubUserProvider(userId));
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined,
                  size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Could not load profile',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(_pubUserProvider(userId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (user) => _ProfileBody(user: user),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.user});
  final UserModel user;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool _showForm = false;
  int _draftRating = 5;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final myId = ref.read(authProvider).userId;
    if (myId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to send a message.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (myId == widget.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot message yourself.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final convId =
          await ref.read(apiServiceProvider).findOrCreateConversation(
                initiatorId: myId,
                recipientId: widget.user.id,
                subject: 'Enquiry to ${widget.user.fullName}',
              );
      if (mounted) context.push('/messages/$convId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start conversation: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitReview() async {
    setState(() => _submitting = true);
    try {
      final reviewerId = ref.read(authProvider).userId;
      await ref.read(apiServiceProvider).createAgentReview(
            agentId: widget.user.id,
            rating: _draftRating,
            title: _titleCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            reviewerId: reviewerId,
          );
      ref.invalidate(_pubReviewsProvider(widget.user.id));
      ref.invalidate(_pubStatsProvider(widget.user.id));
      if (mounted) {
        setState(() {
          _showForm = false;
          _submitting = false;
          _titleCtrl.clear();
          _bodyCtrl.clear();
          _draftRating = 5;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final isOwnProfile = auth.userId == user.id;
    final canReview = auth.isAuthenticated && !isOwnProfile;
    final isAgentRole = user.role == 'agent' ||
        user.role == 'company' ||
        user.role == 'organization';

    final statsAsync =
        isAgentRole ? ref.watch(_pubStatsProvider(user.id)) : null;
    final reviewsAsync = ref.watch(_pubReviewsProvider(user.id));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, cs.primaryContainer],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: cs.onPrimary.withValues(alpha: 0.2),
                  backgroundImage: (user.avatarUrl != null &&
                          user.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(user.avatarUrl!)
                      : null,
                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                      ? Text(
                          _initials(user.firstName, user.lastName),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                _RoleChip(role: user.role),
                if (user.agencyName != null &&
                    user.agencyName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    user.agencyName!,
                    style: TextStyle(
                      color: cs.onPrimary.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    user.bio!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onPrimary.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // ── Stats ─────────────────────────────────────────────────────────
          if (isAgentRole && statsAsync != null)
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _StatsRow(stats: stats),
              ),
            ),

          const SizedBox(height: 16),

          // ── Contact details ───────────────────────────────────────────────
          if (user.phone != null ||
              user.licenseNumber != null ||
              user.residingCountry != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ContactCard(user: user),
            ),

          // ── Message button ────────────────────────────────────────────────
          if (!isOwnProfile) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _sendMessage,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Send Message'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),

          // ── Reviews ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Reviews',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (canReview && !_showForm)
                      TextButton.icon(
                        onPressed: () => setState(() => _showForm = true),
                        icon: const Icon(Icons.rate_review_outlined, size: 16),
                        label: const Text('Write a review'),
                      ),
                  ],
                ),
                // Review form
                if (_showForm) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Rating',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(
                              5,
                              (i) => GestureDetector(
                                onTap: () =>
                                    setState(() => _draftRating = i + 1),
                                child: Icon(
                                  i < _draftRating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Title (optional)',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _bodyCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Comment (optional)',
                              isDense: true,
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () =>
                                        setState(() => _showForm = false),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _submitting ? null : _submitReview,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Submit'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                reviewsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text(
                    'Could not load reviews: $e',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  data: (reviews) {
                    if (reviews.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No reviews yet. Be the first to review!',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReviewSummary(reviews: reviews),
                        const SizedBox(height: 8),
                        ...reviews.map((r) => _ReviewTile(review: r)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Role chip ────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = switch (role) {
      'agent' => 'Agent',
      'company' => 'Company',
      'organization' => 'Organisation',
      'admin' => 'Admin',
      _ => 'Member',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: cs.onPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: cs.onPrimary.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: cs.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalListings =
        (stats['total_properties'] as num?)?.toInt() ?? 0;
    final totalReviews =
        (stats['total_reviews'] as num?)?.toInt() ?? 0;
    final avgRating =
        (stats['avg_rating'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.home_outlined,
            label: 'Listings',
            value: '$totalListings',
          ),
          _StatItem(
            icon: Icons.star_outline_rounded,
            label: 'Avg Rating',
            value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '—',
            valueColor: avgRating > 0 ? Colors.amber[700] : null,
          ),
          _StatItem(
            icon: Icons.rate_review_outlined,
            label: 'Reviews',
            value: '$totalReviews',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 22, color: cs.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor ?? cs.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

// ─── Contact card ─────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <(IconData, String)>[
      if (user.phone != null && user.phone!.isNotEmpty)
        (Icons.phone_outlined, user.phone!),
      if (user.licenseNumber != null && user.licenseNumber!.isNotEmpty)
        (Icons.badge_outlined, 'License: ${user.licenseNumber}'),
      if (user.residingCountry != null && user.residingCountry!.isNotEmpty)
        (Icons.location_city_outlined, user.residingCountry!),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final (icon, text) = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 18,
                        color: cs.primary.withValues(alpha: 0.7)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              if (e.key < items.length - 1)
                const Divider(height: 1, indent: 46),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Review summary ───────────────────────────────────────────────────────────

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.reviews});
  final List<ReviewModel> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();
    final avg =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: Colors.amber[700], size: 20),
          const SizedBox(width: 4),
          Text(
            avg.toStringAsFixed(1),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            '  (${reviews.length} review${reviews.length != 1 ? 's' : ''})',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ─── Review tile ──────────────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  size: 14,
                  color: Colors.amber[700],
                ),
              ),
              const Spacer(),
              Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          if (review.title != null && review.title!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.title!,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
          if (review.body != null && review.body!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              review.body!,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[700], height: 1.4),
            ),
          ],
          const Divider(height: 16),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _initials(String first, String last) {
  final f = first.isNotEmpty ? first[0].toUpperCase() : '';
  final l = last.isNotEmpty ? last[0].toUpperCase() : '';
  final result = '$f$l';
  return result.isNotEmpty ? result : '?';
}
