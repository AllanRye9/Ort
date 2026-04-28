import 'package:flutter/material.dart';

/// Responsive layout breakpoints (logical pixels).
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isMobile => screenWidth < Breakpoints.mobile;
  bool get isTablet =>
      screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.desktop;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// True for tablet or desktop (i.e. screen is wide enough for side nav).
  bool get isWide => screenWidth >= Breakpoints.mobile;

  /// Number of grid columns appropriate for the current screen width.
  int get gridColumns {
    if (screenWidth >= Breakpoints.desktop) return 4;
    if (screenWidth >= Breakpoints.tablet) return 3;
    return 2;
  }

  /// Horizontal content padding appropriate for the current screen width.
  EdgeInsets get contentPadding {
    if (isDesktop) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 8);
    }
    if (isWide) return const EdgeInsets.symmetric(horizontal: 24, vertical: 8);
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  /// Max content width for centred layouts (auth cards etc.).
  double get maxContentWidth => isDesktop ? 1100 : double.infinity;
}

/// Wraps [child] in a centred, max-width card — used on auth screens when the
/// viewport is wider than [Breakpoints.mobile].
class AuthCardWrapper extends StatelessWidget {
  const AuthCardWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) return child;

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.all(32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
