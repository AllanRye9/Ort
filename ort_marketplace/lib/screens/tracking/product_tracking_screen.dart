import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';

/// Maps backend status strings to human-readable labels and icons.
const _kStatusMeta = <String, ({String label, IconData icon, Color color})>{
  'order_placed':       (label: 'Order Placed',        icon: Icons.receipt_long_outlined,       color: Color(0xFF6B7280)),
  'processing':         (label: 'Processing',          icon: Icons.settings_outlined,           color: Color(0xFF3B82F6)),
  'packed':             (label: 'Packed',              icon: Icons.inventory_2_outlined,        color: Color(0xFF8B5CF6)),
  'shipped':            (label: 'Shipped',             icon: Icons.local_shipping_outlined,     color: Color(0xFFF59E0B)),
  'in_transit':         (label: 'In Transit',          icon: Icons.directions_car_outlined,     color: Color(0xFFF97316)),
  'out_for_delivery':   (label: 'Out for Delivery',    icon: Icons.delivery_dining_outlined,    color: Color(0xFF10B981)),
  'delivered':          (label: 'Delivered',           icon: Icons.check_circle_outline,        color: Color(0xFF22C55E)),
  'cancelled':          (label: 'Cancelled',           icon: Icons.cancel_outlined,             color: Color(0xFFEF4444)),
};

const _kAllStatuses = [
  'order_placed', 'processing', 'packed', 'shipped',
  'in_transit', 'out_for_delivery', 'delivered', 'cancelled',
];

final _trackingProvider = FutureProvider.autoDispose
    .family<List<ProductTrackingModel>, int>((ref, orderId) async {
  final data = await ref
      .read(apiServiceProvider)
      .getTrackingEvents(orderId: orderId);
  return data
      .map((e) => ProductTrackingModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Full-screen animated product tracking timeline screen.
///
/// Pass [orderId] to view tracking for an order.
/// Agents / companies / organisations with appropriate roles can add
/// new tracking events via the + FAB.
class ProductTrackingScreen extends ConsumerStatefulWidget {
  const ProductTrackingScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<ProductTrackingScreen> createState() =>
      _ProductTrackingScreenState();
}

class _ProductTrackingScreenState extends ConsumerState<ProductTrackingScreen>
    with TickerProviderStateMixin {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Poll every 10 seconds for real-time updates.
    // Stops automatically when a terminal status is reached.
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      // Read last known events without triggering a rebuild
      final async = ref.read(_trackingProvider(widget.orderId));
      final events = async.valueOrNull;
      if (events != null && events.isNotEmpty) {
        final lastStatus = events.last.status;
        if (lastStatus == 'delivered' || lastStatus == 'cancelled') {
          _refreshTimer?.cancel();
          return;
        }
      }
      ref.invalidate(_trackingProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool _canPostUpdate(String? role) =>
      role == 'agent' || role == 'company' || role == 'organization';

  Future<void> _addUpdate() async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddTrackingSheet(orderId: widget.orderId),
    );
    if (result != null && mounted) {
      ref.invalidate(_trackingProvider(widget.orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canUpdate = _canPostUpdate(auth.role);
    final async = ref.watch(_trackingProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId} Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(_trackingProvider(widget.orderId)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: canUpdate
          ? FloatingActionButton.extended(
              onPressed: _addUpdate,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Post Update'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (events) => events.isEmpty
            ? _EmptyTrackingState(
                canUpdate: canUpdate, onAdd: canUpdate ? _addUpdate : null)
            : _TrackingTimeline(
                events: events,
                orderId: widget.orderId,
              ),
      ),
    );
  }
}

class _EmptyTrackingState extends StatelessWidget {
  const _EmptyTrackingState({required this.canUpdate, this.onAdd});
  final bool canUpdate;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No tracking updates yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (canUpdate) ...[
              const SizedBox(height: 8),
              const Text('Tap the button below to post the first update.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Post First Update'),
              ),
            ],
          ],
        ),
      );
}

class _TrackingTimeline extends StatefulWidget {
  const _TrackingTimeline({required this.events, required this.orderId});
  final List<ProductTrackingModel> events;
  final int orderId;

  @override
  State<_TrackingTimeline> createState() => _TrackingTimelineState();
}

class _TrackingTimelineState extends State<_TrackingTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_TrackingTimeline old) {
    super.didUpdateWidget(old);
    if (widget.events.length != old.events.length) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.events;
    final lastStatus = events.isNotEmpty ? events.last.status : null;
    final meta = lastStatus != null ? _kStatusMeta[lastStatus] : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Current status hero ────────────────────────────────────────────
          if (meta != null)
            AnimatedBuilder(
              animation: _anim,
              builder: (ctx, child) => Opacity(
                opacity: _anim.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _anim.value)),
                  child: child,
                ),
              ),
              child: Card(
                color: meta.color.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(meta.icon, color: meta.color, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Status',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                            Text(
                              meta.label,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: meta.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),
          Text(
            'Tracking History',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // ── Timeline items ─────────────────────────────────────────────────
          ...events.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final isLast = i == events.length - 1;
            final m = _kStatusMeta[e.status];
            final icon = m?.icon ?? Icons.circle_outlined;
            final color = m?.color ?? Colors.grey;
            final label = m?.label ?? e.status;

            return AnimatedBuilder(
              animation: _anim,
              builder: (ctx, child) {
                final delay = (i / events.length) * 0.6;
                final t = (((_anim.value - delay) / (1 - delay))
                    .clamp(0.0, 1.0));
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(30 * (1 - t), 0),
                    child: child,
                  ),
                );
              },
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline connector column
                    SizedBox(
                      width: 36,
                      child: Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Icon(icon, size: 16, color: color),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4),
                                color: Colors.grey[300],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Event details
                    Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.only(bottom: isLast ? 0 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: color,
                              ),
                            ),
                            if (e.location != null &&
                                e.location!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      e.location!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (e.description != null &&
                                e.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                e.description!,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[700]),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(e.createdAt),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Bottom sheet for posting a new tracking update (agent / company / org).
class _AddTrackingSheet extends ConsumerStatefulWidget {
  const _AddTrackingSheet({required this.orderId});
  final int orderId;

  @override
  ConsumerState<_AddTrackingSheet> createState() => _AddTrackingSheetState();
}

class _AddTrackingSheetState extends ConsumerState<_AddTrackingSheet> {
  String _status = 'processing';
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final userId = ref.read(authProvider).userId;
      await ref.read(apiServiceProvider).createTrackingEvent({
        'order_id': widget.orderId,
        'status': _status,
        if (_locationCtrl.text.trim().isNotEmpty)
          'location': _locationCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (userId != null) 'created_by_user_id': userId,
      });
      if (mounted) Navigator.pop(context, {'posted': true});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Post Tracking Update',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status *'),
            items: _kAllStatuses
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                          _kStatusMeta[s]?.label ?? s),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Current Location (optional)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Additional Notes (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Post Update'),
            ),
          ),
        ],
      ),
    );
  }
}
