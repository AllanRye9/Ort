# Ort Navigation System - Implementation Guide

## Overview

The Ort marketplace now has a comprehensive navigation system that enables users to navigate back and forth effortlessly across the application. The system includes:

1. **OrtAppBar** - Standardized app bar with back button and breadcrumbs
2. **NavigationService** - Centralized navigation state management
3. **NavigationHelper** - Convenient methods for common navigation patterns
4. **Navigation Widgets** - Drawer, FAB, and quick navigation components
5. **Context Extensions** - Convenient navigation methods on BuildContext

## Components

### 1. OrtAppBar Widget

A reusable app bar used across all screens with consistent styling and navigation.

#### Usage:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: OrtAppBar(
      title: 'Agriculture Listings',
      breadcrumbs: [
        ('Agriculture', () => context.goAgriculture()),
        ('List', () {}),
      ],
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => context.push('/agriculture/create'),
        ),
      ],
    ),
    body: _buildBody(),
  );
}
```

#### Parameters:

- `title` (required) - Main title for the app bar
- `breadcrumbs` - List of (label, callback) tuples for breadcrumb navigation
- `actions` - Action buttons to display on the right
- `leading` - Custom leading widget (overrides default back button)
- `showBackButton` - Whether to show back button (default: true)
- `onBackPressed` - Custom callback for back button
- `backgroundColor` - Custom app bar color
- `elevation` - App bar elevation

### 2. NavigationService

Centralized service for managing navigation state and breadcrumbs.

#### Basic Usage:

```dart
import '../../core/navigation_service.dart';

// Set breadcrumbs for current screen
NavigationService().setBreadcrumbs([
  ('Agriculture', () => context.goAgriculture()),
  ('Detail', () {}),
]);

// Clear breadcrumbs
NavigationService().clearBreadcrumbs();

// Get current breadcrumbs
final breadcrumbs = NavigationService().breadcrumbs;
```

### 3. Navigation Context Extensions

Convenient extension methods on BuildContext for navigation.

#### Available Methods:

```dart
// Navigate to main sections
context.goHome();
context.goProperties();
context.goAgriculture();
context.goManufacturing();
context.goMessages();
context.goProfile();
context.goOrders();
context.goMyListings();
context.goSaved();
context.goWallet();
context.goNotifications();
context.goSettings();
context.goAiAssistant();

// Create breadcrumbs for sections
final breadcrumbs = NavigationContextExtension.propertiesBreadcrumbs(
  context,
  currentPath: GoRouterState.of(context).matchedLocation,
  propertyId: propertyId,
);
```

### 4. NavigationHelper

Helper class for managing common screen transitions with automatic breadcrumbs.

#### Usage:

```dart
import '../../core/navigation_service.dart';

// Navigate to detail screen with breadcrumbs
NavigationHelper.goToDetail(
  context,
  section: 'agriculture',
  id: listingId,
  detailPath: '/agriculture/$listingId',
);

// Navigate to edit screen with breadcrumbs
NavigationHelper.goToEdit(
  context,
  section: 'agriculture',
  id: listingId,
  editPath: '/agriculture/$listingId/edit',
);

// Navigate to create screen with breadcrumbs
NavigationHelper.goToCreate(
  context,
  section: 'agriculture',
  createPath: '/agriculture/create',
);

// Show navigation menu
NavigationHelper.showNavigationMenu(context);
```

### 5. Navigation Widgets

#### QuickNavigationDrawer

A comprehensive navigation drawer with all app sections.

```dart
Scaffold(
  drawer: const QuickNavigationDrawer(),
  appBar: OrtAppBar(title: 'Screen Title'),
  body: _buildBody(),
);
```

#### QuickActionFab

Floating action button for quick access to create new listings.

```dart
Scaffold(
  appBar: OrtAppBar(title: 'Screen Title'),
  floatingActionButton: const QuickActionFab(),
  body: _buildBody(),
);
```

## Implementation Examples

### Example 1: Update List Screen

```dart
import '../../core/navigation_service.dart';
import '../../widgets/navigation_widgets.dart';

class AgricultureScreen extends ConsumerWidget {
  const AgricultureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      drawer: const QuickNavigationDrawer(),
      appBar: OrtAppBar(
        title: 'Agriculture',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => NavigationHelper.goToCreate(
              context,
              section: 'agriculture',
              createPath: '/agriculture/create',
            ),
          ),
        ],
      ),
      floatingActionButton: const QuickActionFab(),
      body: _buildListView(context, ref),
    );
  }

  Widget _buildListView(BuildContext context, WidgetRef ref) {
    // ... implementation
  }
}
```

### Example 2: Update Detail Screen

```dart
import '../../core/navigation_service.dart';
import '../../widgets/navigation_widgets.dart';

class AgricultureDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const AgricultureDetailScreen({super.key, required this.id});

  @override
  ConsumerState<AgricultureDetailScreen> createState() => _AgricultureDetailScreenState();
}

class _AgricultureDetailScreenState extends ConsumerState<AgricultureDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Set breadcrumbs when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService().setBreadcrumbs([
        ('Agriculture', () => context.goAgriculture()),
        ('Detail', () {}),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OrtAppBar(
        title: 'Commodity Detail',
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => NavigationHelper.goToEdit(
              context,
              section: 'agriculture',
              id: widget.id,
              editPath: '/agriculture/${widget.id}/edit',
            ),
          ),
        ],
      ),
      body: _buildDetail(),
    );
  }

  Widget _buildDetail() {
    // ... implementation
  }
}
```

### Example 3: Update Create Screen

```dart
import '../../core/navigation_service.dart';
import '../../widgets/navigation_widgets.dart';

class AgricultureCreateScreen extends ConsumerStatefulWidget {
  const AgricultureCreateScreen({super.key});

  @override
  ConsumerState<AgricultureCreateScreen> createState() => _AgricultureCreateScreenState();
}

class _AgricultureCreateScreenState extends ConsumerState<AgricultureCreateScreen> {
  @override
  void initState() {
    super.initState();
    // Set breadcrumbs when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService().setBreadcrumbs([
        ('Agriculture', () => context.goAgriculture()),
        ('Create', () {}),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OrtAppBar(
        title: 'Create Agriculture Listing',
        showBackButton: true,
        onBackPressed: () => context.pop(),
      ),
      body: _buildForm(),
    );
  }

  Widget _buildForm() {
    // ... implementation
  }
}
```

### Example 4: Manufacturing Screens

Same pattern applies to manufacturing, properties, and other modules:

```dart
class ManufacturingDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const ManufacturingDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ManufacturingDetailScreen> createState() =>
      _ManufacturingDetailScreenState();
}

class _ManufacturingDetailScreenState
    extends ConsumerState<ManufacturingDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService().setBreadcrumbs([
        ('Manufacturing', () => context.goManufacturing()),
        ('Detail', () {}),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OrtAppBar(
        title: 'Product Detail',
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/manufacturing/${widget.id}/edit'),
          ),
        ],
      ),
      body: _buildDetail(),
    );
  }

  Widget _buildDetail() {
    // ... implementation
  }
}
```

## Navigation Patterns

### Pattern 1: List → Detail → Edit → List

```dart
// On list item tap:
NavigationHelper.goToDetail(
  context,
  section: 'agriculture',
  id: listingId,
  detailPath: '/agriculture/$listingId',
);

// On edit button in detail:
NavigationHelper.goToEdit(
  context,
  section: 'agriculture',
  id: widget.id,
  editPath: '/agriculture/${widget.id}/edit',
);

// Back button returns user through the stack:
// Edit → Detail → List
```

### Pattern 2: Home → Search Results → Detail

```dart
// Navigation is automatic through GoRouter
// Breadcrumbs show the path:
// [Home / Search / Detail]
```

### Pattern 3: Quick Create from FAB

```dart
// QuickActionFab shows create options:
// - Property
// - Agriculture
// - Manufacturing

// Each navigates to the create screen with breadcrumbs
```

## Best Practices

1. **Always Set Breadcrumbs** - Use `WidgetsBinding.instance.addPostFrameCallback` in `initState` to set breadcrumbs when entering a detail/edit screen

2. **Use NavigationHelper for Consistency** - Use `NavigationHelper.goToDetail()` instead of `context.push()` to ensure consistent breadcrumb handling

3. **Provide Back Navigation** - Always include a back button in your app bar for non-list screens

4. **Include a Drawer** - Add `QuickNavigationDrawer` to main screens for easy access to all sections

5. **Use FAB for Create Actions** - Include `QuickActionFab` on list screens for quick listing creation

6. **Clear Navigation on Sign Out** - Use `NavigationService().clearNavigationStack()` on logout

7. **Consistent Naming** - Use section names: 'agriculture', 'manufacturing', 'properties', 'orders', 'messages'

## Migration Checklist

### For Each Screen:

- [ ] Replace default AppBar with `OrtAppBar`
- [ ] Add import for `navigation_service.dart` and `navigation_widgets.dart`
- [ ] Add `NavigationService().setBreadcrumbs()` in `initState()` for detail screens
- [ ] Update navigation calls to use context extensions (`context.goXxx()`)
- [ ] Add `QuickNavigationDrawer` to list screens
- [ ] Add `QuickActionFab` to list screens where applicable
- [ ] Use `NavigationHelper` for navigating to create/edit/detail screens
- [ ] Test back button navigation thoroughly

## Common Issues & Solutions

### Breadcrumbs not showing?
- Make sure you're setting them in `initState()` with `WidgetsBinding.instance.addPostFrameCallback()`
- Check that `OrtAppBar` receives the `breadcrumbs` parameter

### Back button not working?
- Ensure `showBackButton: true` (default)
- Verify GoRouter can pop (check navigation stack)
- Check that parent screen is properly set up

### Navigation not smooth?
- Use `context.push()` for forward navigation (adds to stack)
- Use `context.go()` only when replacing entire stack
- Use `context.pop()` to go back

## API Reference

### OrtAppBar
- `title: String` - Required
- `breadcrumbs: List<(String, VoidCallback)>?`
- `actions: List<Widget>?`
- `leading: Widget?`
- `showBackButton: bool`
- `onBackPressed: VoidCallback?`

### NavigationService
- `setBreadcrumbs(List?)`
- `clearBreadcrumbs()`
- `getNavigationStack() → List<String>`
- `clearNavigationStack()`

### NavigationHelper
- `goToDetail(context, section, id, detailPath)`
- `goToEdit(context, section, id, editPath)`
- `goToCreate(context, section, createPath)`
- `showNavigationMenu(context)`

### Context Extensions
- `goHome()`, `goProperties()`, `goAgriculture()`, etc.
- `*Breadcrumbs()` static methods for creating breadcrumbs
