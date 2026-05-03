import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';

/// A button that lets the listing owner purchase an ad promotion.
///
/// Usage:
/// ```dart
/// PromoteListingButton(listingType: 'property', listingId: 42)
/// ```
///
/// Promotion plans (points = cash units at 1:1 ratio):
///   7  days  →  10 points
///   30 days  →  26 points
///   365 days → 300 points
class PromoteListingButton extends ConsumerStatefulWidget {
  const PromoteListingButton({
    super.key,
    required this.listingType,
    required this.listingId,
  });

  /// One of: "property", "agriculture", "manufacturing"
  final String listingType;
  final int listingId;

  @override
  ConsumerState<PromoteListingButton> createState() =>
      _PromoteListingButtonState();
}

class _PromoteListingButtonState extends ConsumerState<PromoteListingButton> {
  static const _plans = [
    (days: 7, points: 10, label: '7 days – 10 pts'),
    (days: 30, points: 26, label: '30 days – 26 pts'),
    (days: 365, points: 300, label: '1 year – 300 pts'),
  ];

  bool _loading = false;

  Future<void> _openPortal() async {
    int? selectedDays;

    // Fetch wallet balance to show the user.
    int walletPoints = 0;
    try {
      final data = await ref.read(apiServiceProvider).getMyWallet();
      walletPoints = data['points'] as int? ?? 0;
    } catch (_) {}

    if (!mounted) return;

    final confirmed = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Promote This Listing'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your balance: $walletPoints pts',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a promotion duration. Your listing will appear at the '
                'top (hotspot) of search results for the chosen period.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              ..._plans.map(
                (plan) => RadioListTile<int>(
                  title: Text(plan.label),
                  subtitle: Text(
                    walletPoints >= plan.points
                        ? 'Affordable'
                        : 'Need ${plan.points - walletPoints} more pts',
                    style: TextStyle(
                      fontSize: 11,
                      color: walletPoints >= plan.points
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  value: plan.days,
                  groupValue: selectedDays,
                  onChanged: (v) => setDialogState(() => selectedDays = v),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedDays == null
                  ? null
                  : () => Navigator.pop(ctx, selectedDays),
              child: const Text('Promote'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == null || !mounted) return;
    setState(() => _loading = true);

    try {
      await ref.read(apiServiceProvider).createPromotion(
            listingType: widget.listingType,
            listingId: widget.listingId,
            durationDays: confirmed,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.star_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Listing promoted for $confirmed day${confirmed == 1 ? '' : 's'}! 🚀',
                ),
              ),
            ]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promotion failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      // Override the global theme's `minimumSize: Size(double.infinity, 52)`.
      // This is an inline compact button, not a full-width form button, so it
      // should size to its content. Without this override, the infinite minimum
      // width propagates as BoxConstraints(w=Infinity) inside unconstrained
      // contexts (e.g. Row → SingleChildScrollView), crashing layout.
      // Height 44 matches kMinInteractiveDimension (Flutter tap-target default).
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
      onPressed: _loading ? null : _openPortal,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.star_border_rounded, size: 18),
      label: const Text('Promote'),
    );
  }
}
