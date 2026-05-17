# Ort Navigation - Quick Reference

## Most Common Navigation Tasks

### 1. Update List Screen to Add Navigation UI

**Before:**
```dart
class AgricultureScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agriculture')),
      body: _buildList(),
    );
  }
}
```

**After:**
```dart
import '../../core/navigation_service.dart';
import '../../widgets/navigation_widgets.dart';

class AgricultureScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      drawer: const QuickNavigationDrawer(),
      appBar: OrtAppBar(
        title: 'Agriculture',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/agriculture/create'),
          ),
        ],
      ),
      floatingActionButton: const QuickActionFab(),
      body: _buildList(),
    );
  }
}
```

### 2. Update Detail Screen to Add Breadcrumbs

**Before:**
```dart
class AgricultureDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const AgricultureDetailScreen({super.key, required this.id});

  @override
  ConsumerState<AgricultureDetailScreen> createState() =>
      _AgricultureDetailScreenState();
}

class _AgricultureDetailScreenState
    extends ConsumerState<AgricultureDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail')),
      body: _buildDetail(),
    );
  }
}
```

**After:**
```dart
import '../../core/navigation_service.dart';
import '../../widgets/navigation_widgets.dart';

class AgricultureDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const AgricultureDetailScreen({super.key, required this.id});

  @override
  ConsumerState<AgricultureDetailScreen> createState() =>
      _AgricultureDetailScreenState();
}

class _AgricultureDetailScreenState
    extends ConsumerState<AgricultureDetailScreen> {
  @override
  void initState() {
    super.initState();
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
      appBar: OrtAppBar(title: 'Commodity Detail'),
      body: _buildDetail(),
    );
  }
}
```

### 3. Navigate to Another Section

**Old Way:**
```dart
context.go('/agriculture');
```

**New Way (Better - Using Extension):**
```dart
context.goAgriculture();
```

### 4. Navigate to Create Screen with Breadcrumbs

```dart
NavigationHelper.goToCreate(
  context,
  section: 'agriculture',
  createPath: '/agriculture/create',
);
```

### 5. Navigate to Detail Screen with Breadcrumbs

```dart
NavigationHelper.goToDetail(
  context,
  section: 'agriculture',
  id: listingId,
  detailPath: '/agriculture/$listingId',
);
```

### 6. Navigate to Edit Screen with Breadcrumbs

```dart
NavigationHelper.goToEdit(
  context,
  section: 'agriculture',
  id: widget.id,
  editPath: '/agriculture/${widget.id}/edit',
);
```

## Navigation Context Extensions

### Jump to Any Section
```dart
context.goHome();           // → Home
context.goProperties();     // → Properties
context.goAgriculture();    // → Agriculture
context.goManufacturing();  // → Manufacturing
context.goMessages();       // → Messages
context.goProfile();        // → Profile
context.goOrders();         // → Orders
context.goMyListings();     // → My Listings
context.goSaved();          // → Saved
context.goWallet();         // → Wallet
context.goNotifications();  // → Notifications
context.goSettings();       // → Settings
context.goAiAssistant();    // → AI Assistant
```

## Navigation Widgets

### Quick Navigation Drawer
Adds a comprehensive navigation drawer to any screen:
```dart
Scaffold(
  drawer: const QuickNavigationDrawer(),
  appBar: OrtAppBar(title: 'Title'),
  body: _buildBody(),
);
```

### Quick Action FAB
Adds a floating button for quick listing creation:
```dart
Scaffold(
  appBar: OrtAppBar(title: 'Title'),
  floatingActionButton: const QuickActionFab(),
  body: _buildBody(),
);
```

### Ort App Bar
Replaces standard AppBar with navigation features:
```dart
appBar: OrtAppBar(
  title: 'Screen Title',
  breadcrumbs: [
    ('Parent', () => context.goParent()),
    ('Current', () {}),
  ],
  actions: [
    IconButton(icon: const Icon(Icons.add), onPressed: () {}),
  ],
  showBackButton: true,
),
```

## Imports Needed

Add these imports to use navigation features:
```dart
import '../../core/navigation_service.dart';
import '../../widgets/navigation_widgets.dart';
```

Or for context extensions only:
```dart
import '../../core/navigation_service.dart';
```

## Screen-by-Screen Checklist

### For List Screens (agriculture, properties, manufacturing)
- [ ] Import navigation modules
- [ ] Replace `AppBar` with `OrtAppBar`
- [ ] Add `drawer: const QuickNavigationDrawer()`
- [ ] Add `floatingActionButton: const QuickActionFab()` (optional)
- [ ] Add create button in app bar actions

### For Detail Screens
- [ ] Import navigation modules
- [ ] Set breadcrumbs in `initState()`
- [ ] Replace `AppBar` with `OrtAppBar`
- [ ] Add edit button in app bar actions (if applicable)

### For Create/Edit Screens
- [ ] Import navigation modules
- [ ] Set breadcrumbs in `initState()`
- [ ] Replace `AppBar` with `OrtAppBar`
- [ ] Use `showBackButton: true` (default)

### For Special Screens (Search, Settings, etc.)
- [ ] Import navigation modules
- [ ] Replace `AppBar` with `OrtAppBar`
- [ ] Add breadcrumbs if nested flow

## Copy-Paste Templates

### List Screen Template
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation_service.dart';
import '../../widgets/navigation_widgets.dart';

class MyListScreen extends ConsumerWidget {
  const MyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      drawer: const QuickNavigationDrawer(),
      appBar: OrtAppBar(
        title: 'My Items',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/my-items/create'),
          ),
        ],
      ),
      floatingActionButton: const QuickActionFab(),
      body: Center(child: Text('List content here')),
    );
  }
}
```

### Detail Screen Template
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation_service.dart';
import '../../widgets/navigation_widgets.dart';

class MyDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const MyDetailScreen({super.key, required this.id});

  @override
  ConsumerState<MyDetailScreen> createState() => _MyDetailScreenState();
}

class _MyDetailScreenState extends ConsumerState<MyDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService().setBreadcrumbs([
        ('My Items', () => context.go('/my-items')),
        ('Detail', () {}),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OrtAppBar(
        title: 'Item Detail',
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/my-items/${widget.id}/edit'),
          ),
        ],
      ),
      body: Center(child: Text('Detail content for item ${widget.id}')),
    );
  }
}
```

### Create Screen Template
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/navigation_service.dart';
import '../../widgets/navigation_widgets.dart';

class MyCreateScreen extends ConsumerStatefulWidget {
  const MyCreateScreen({super.key});

  @override
  ConsumerState<MyCreateScreen> createState() => _MyCreateScreenState();
}

class _MyCreateScreenState extends ConsumerState<MyCreateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService().setBreadcrumbs([
        ('My Items', () => context.go('/my-items')),
        ('Create', () {}),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OrtAppBar(
        title: 'Create Item',
        showBackButton: true,
      ),
      body: Center(child: Text('Create form here')),
    );
  }
}
```

## Test Navigation Flow

1. **Start at Home** → tap Agriculture
2. **View List** → see drawer and FAB
3. **Create Item** → breadcrumbs show [Agriculture / Create]
4. **Back Button** → returns to Agriculture list
5. **Tap Item** → breadcrumbs show [Agriculture / Detail]
6. **Edit Item** → breadcrumbs show [Agriculture / Detail / Edit]
7. **Back Multiple Times** → stack navigation works smoothly
8. **Use Drawer** → jump directly to any section

## Troubleshooting

**Breadcrumbs not showing?**
- Check imports are correct
- Verify `WidgetsBinding.instance.addPostFrameCallback()` is in `initState()`
- Make sure `OrtAppBar` has `breadcrumbs` parameter

**Back button missing?**
- Add `showBackButton: true` to `OrtAppBar`
- Or provide custom `leading` widget

**Navigation feels sluggish?**
- Use `context.push()` for forward navigation
- Use `context.go()` only for route replacement
- Avoid unnecessary rebuilds in navigation callbacks

**Drawer not showing?**
- Add `drawer: const QuickNavigationDrawer()` to Scaffold
- Works on mobile and tablet layouts
