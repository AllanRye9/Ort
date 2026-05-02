import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/responsive.dart';

/// A single quick-action definition.
class QuickAction {
  const QuickAction(this.icon, this.label, this.route, this.color);
  final IconData icon;
  final String label;
  final String route;
  final Color color;
}

// ─── Role-specific quick actions ─────────────────────────────────────────────

const agentQuickActions = [
  QuickAction(Icons.add_business_outlined, 'New Listing', '/properties/create', Color(0xFF1B5E20)),
  QuickAction(Icons.list_alt_outlined, 'My Listings', '/my-listings', Color(0xFF1565C0)),
  QuickAction(Icons.people_outline, 'My Clients', '/my-clients', Color(0xFF6A1B9A)),
  QuickAction(Icons.bar_chart_outlined, 'Analytics', '/analytics', Color(0xFFE65100)),
];

const companyQuickActions = [
  QuickAction(Icons.add_box_outlined, 'Add Product', '/manufacturing/create', Color(0xFFE65100)),
  QuickAction(Icons.list_alt_outlined, 'My Listings', '/my-listings', Color(0xFF1565C0)),
  QuickAction(Icons.shopping_bag_outlined, 'My Orders', '/orders', Color(0xFF2E7D32)),
  QuickAction(Icons.chat_bubble_outline, 'Messages', '/messages', Color(0xFF6A1B9A)),
];

const organizationQuickActions = [
  QuickAction(Icons.add_circle_outline, 'Add Listing', '/agriculture/create', Color(0xFF2E7D32)),
  QuickAction(Icons.list_alt_outlined, 'My Listings', '/my-listings', Color(0xFF1565C0)),
  QuickAction(Icons.shopping_bag_outlined, 'My Orders', '/orders', Color(0xFFE65100)),
  QuickAction(Icons.chat_bubble_outline, 'Messages', '/messages', Color(0xFF6A1B9A)),
];

const userQuickActions = [
  QuickAction(Icons.apartment_outlined, 'Properties', '/properties', Color(0xFF1B5E20)),
  QuickAction(Icons.grass_outlined, 'Agriculture', '/agriculture', Color(0xFF2E7D32)),
  QuickAction(Icons.precision_manufacturing_outlined, 'Products', '/manufacturing', Color(0xFFE65100)),
  QuickAction(Icons.calculate_outlined, 'Distance', '/distance-calculator', Color(0xFF1565C0)),
];

// ─── Grid widget ──────────────────────────────────────────────────────────────

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions});
  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final cols = context.isWide ? actions.length : 4;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 0.85,
      children: List.generate(
        actions.length,
        (i) => _AnimatedEntry(
          delay: Duration(milliseconds: 80 * i),
          child: _QuickActionTile(action: actions[i]),
        ),
      ),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.action});
  final QuickAction action;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) async {
          await _scaleCtrl.reverse();
          if (mounted) context.go(widget.action.route);
        },
        onTapCancel: () => _scaleCtrl.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (_, child) =>
              Transform.scale(scale: _scaleAnim.value, child: child),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.action.color.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(widget.action.icon,
                    color: widget.action.color, size: 26),
              ),
              const SizedBox(height: 6),
              Text(
                widget.action.label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
}

// ─── Animated entry wrapper ───────────────────────────────────────────────────

class _AnimatedEntry extends StatefulWidget {
  const _AnimatedEntry({required this.child, required this.delay});
  final Widget child;
  final Duration delay;

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
