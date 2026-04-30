import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api_service.dart';
import '../../core/location_service.dart';
import '../../models/models.dart';

// ─── Haversine helper ─────────────────────────────────────────────────────────

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final phi1 = lat1 * pi / 180;
  final phi2 = lat2 * pi / 180;
  final dPhi = (lat2 - lat1) * pi / 180;
  final dLambda = (lon2 - lon1) * pi / 180;
  final a = sin(dPhi / 2) * sin(dPhi / 2) +
      cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// ─── Item picker helpers ──────────────────────────────────────────────────────

class _PickedItem {
  const _PickedItem({
    required this.label,
    required this.lat,
    required this.lon,
  });
  final String label;
  final double lat;
  final double lon;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DistanceCalculatorScreen extends ConsumerStatefulWidget {
  const DistanceCalculatorScreen({super.key});

  @override
  ConsumerState<DistanceCalculatorScreen> createState() =>
      _DistanceCalculatorScreenState();
}

class _DistanceCalculatorScreenState
    extends ConsumerState<DistanceCalculatorScreen> {
  final _pointACtrl = TextEditingController();
  final _pointBCtrl = TextEditingController();

  double? _aLat, _aLon;
  double? _bLat, _bLon;
  String? _aLabel, _bLabel;

  bool _loadingA = false;
  bool _loadingB = false;
  bool _resolving = false;

  @override
  void dispose() {
    _pointACtrl.dispose();
    _pointBCtrl.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation({required bool forA}) async {
    setState(() => forA ? _loadingA = true : _loadingB = true);
    final pos = await LocationService.instance.requestAndGetPosition();
    if (!mounted) return;
    setState(() {
      forA ? _loadingA = false : _loadingB = false;
    });
    if (pos == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission denied.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      if (forA) {
        _aLat = pos.latitude;
        _aLon = pos.longitude;
        _aLabel = 'My Location';
        _pointACtrl.text = 'My Location';
      } else {
        _bLat = pos.latitude;
        _bLon = pos.longitude;
        _bLabel = 'My Location';
        _pointBCtrl.text = 'My Location';
      }
    });
  }

  Future<void> _geocodeManual({required bool forA}) async {
    final query = (forA ? _pointACtrl.text : _pointBCtrl.text).trim();
    if (query.isEmpty || query == 'My Location') return;
    setState(() => _resolving = true);
    final result =
        await LocationService.instance.geocodeAddress(query);
    if (!mounted) return;
    setState(() => _resolving = false);
    if (result == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address not found. Try a more specific query.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final (lat, lon) = result;
    setState(() {
      if (forA) {
        _aLat = lat;
        _aLon = lon;
        _aLabel = query;
      } else {
        _bLat = lat;
        _bLon = lon;
        _bLabel = query;
      }
    });
  }

  Future<void> _pickItemForB() async {
    final api = ref.read(apiServiceProvider);
    final picked = await showModalBottomSheet<_PickedItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ItemPickerSheet(api: api),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _bLat = picked.lat;
      _bLon = picked.lon;
      _bLabel = picked.label;
      _pointBCtrl.text = picked.label;
    });
  }

  double? get _distKm {
    if (_aLat == null || _aLon == null || _bLat == null || _bLon == null) {
      return null;
    }
    return _haversineKm(_aLat!, _aLon!, _bLat!, _bLon!);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dist = _distKm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Distance Calculator'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Point A ────────────────────────────────────────────
            Text('Point A', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pointACtrl,
                    decoration: const InputDecoration(
                      hintText: 'City, address or coordinates…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _geocodeManual(forA: true),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                _loadingA
                    ? const SizedBox(
                        width: 36, height: 36,
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton.filled(
                        icon: const Icon(Icons.my_location),
                        onPressed: () => _useMyLocation(forA: true),
                        tooltip: 'Use my location',
                      ),
              ],
            ),
            if (_aLat != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_aLat!.toStringAsFixed(5)}, ${_aLon!.toStringAsFixed(5)}',
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),

            const SizedBox(height: 16),

            // ── Point B ────────────────────────────────────────────
            Text('Point B', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pointBCtrl,
                    decoration: const InputDecoration(
                      hintText: 'City, address, or pick a listing…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _geocodeManual(forA: false),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                _loadingB
                    ? const SizedBox(
                        width: 36, height: 36,
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton.filled(
                        icon: const Icon(Icons.my_location),
                        onPressed: () => _useMyLocation(forA: false),
                        tooltip: 'Use my location',
                      ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  icon: const Icon(Icons.list_outlined),
                  onPressed: _pickItemForB,
                  tooltip: 'Pick a listing',
                ),
              ],
            ),
            if (_bLat != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_bLat!.toStringAsFixed(5)}, ${_bLon!.toStringAsFixed(5)}',
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),

            const SizedBox(height: 20),

            if (_resolving)
              const Center(child: CircularProgressIndicator()),

            // ── Result ─────────────────────────────────────────────
            if (dist != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${dist.toStringAsFixed(2)} km',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '(${(dist * 0.621371).toStringAsFixed(2)} miles)',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                    ),
                    if (_aLabel != null && _bLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'from $_aLabel to $_bLabel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              cs.onPrimaryContainer.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Mini Map ───────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 240,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        (_aLat! + _bLat!) / 2,
                        (_aLon! + _bLon!) / 2,
                      ),
                      initialZoom: _zoomLevel(dist),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ort.marketplace',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(_aLat!, _aLon!),
                              LatLng(_bLat!, _bLon!),
                            ],
                            strokeWidth: 2.5,
                            color: cs.primary,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_aLat!, _aLon!),
                            width: 32,
                            height: 32,
                            child: Icon(Icons.location_on,
                                color: cs.primary, size: 28),
                          ),
                          Marker(
                            point: LatLng(_bLat!, _bLon!),
                            width: 32,
                            height: 32,
                            child: Icon(Icons.flag_outlined,
                                color: cs.secondary, size: 28),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_aLat != null || _bLat != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _aLat == null
                      ? 'Set Point A to calculate distance.'
                      : 'Set Point B to calculate distance.',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55)),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 24),

            // ── Calculate button ───────────────────────────────────
            // Triggers geocoding for any manually entered addresses that
            // haven't been resolved yet, then updates the displayed result.
            ElevatedButton.icon(
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Calculate'),
              onPressed: () async {
                bool changed = false;
                if (_aLat == null &&
                    _pointACtrl.text.trim().isNotEmpty) {
                  await _geocodeManual(forA: true);
                  changed = true;
                }
                if (_bLat == null &&
                    _pointBCtrl.text.trim().isNotEmpty) {
                  await _geocodeManual(forA: false);
                  changed = true;
                }
                if (!changed && mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  double _zoomLevel(double km) {
    if (km < 1) return 14;
    if (km < 5) return 12;
    if (km < 20) return 10;
    if (km < 100) return 8;
    if (km < 500) return 6;
    return 4;
  }
}

// ─── Item picker bottom sheet ─────────────────────────────────────────────────

class _ItemPickerSheet extends ConsumerStatefulWidget {
  const _ItemPickerSheet({required this.api});
  final ApiService api;

  @override
  ConsumerState<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<_ItemPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<PropertyModel>? _props;
  List<AgricultureListingModel>? _agri;
  List<ManufacturingProductModel>? _mfg;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final api = widget.api;
    try {
      final r = await Future.wait([
        api.getPropertiesFiltered(limit: 200),
        api.getAgricultureFiltered(limit: 200),
        api.getManufacturingFiltered(limit: 200),
      ]);
      if (mounted) {
        setState(() {
          _props = (r[0] as List)
              .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _agri = (r[1] as List)
              .map((e) =>
                  AgricultureListingModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _mfg = (r[2] as List)
              .map((e) => ManufacturingProductModel.fromJson(
                  e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Pick a listing',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Properties'),
              Tab(text: 'Agriculture'),
              Tab(text: 'Manufacturing'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _ItemList(
                          items: _props
                              ?.where((p) =>
                                  p.latitude != null && p.longitude != null)
                              .map((p) => _PickedItem(
                                    label: p.title,
                                    lat: p.latitude!,
                                    lon: p.longitude!,
                                  ))
                              .toList() ??
                              [],
                          scrollCtrl: scrollCtrl),
                      _ItemList(
                          items: _agri
                              ?.where((a) =>
                                  a.latitude != null && a.longitude != null)
                              .map((a) => _PickedItem(
                                    label: a.title,
                                    lat: a.latitude!,
                                    lon: a.longitude!,
                                  ))
                              .toList() ??
                              [],
                          scrollCtrl: scrollCtrl),
                      _ItemList(
                          items: _mfg
                              ?.where((m) =>
                                  m.latitude != null && m.longitude != null)
                              .map((m) => _PickedItem(
                                    label: m.title,
                                    lat: m.latitude!,
                                    lon: m.longitude!,
                                  ))
                              .toList() ??
                              [],
                          scrollCtrl: scrollCtrl),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items, required this.scrollCtrl});
  final List<_PickedItem> items;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text('No items with location data.',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      controller: scrollCtrl,
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final item = items[i];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(item.label),
          subtitle: Text(
            '${item.lat.toStringAsFixed(4)}, ${item.lon.toStringAsFixed(4)}',
            style: const TextStyle(fontSize: 11),
          ),
          onTap: () => Navigator.of(ctx).pop(item),
        );
      },
    );
  }
}
