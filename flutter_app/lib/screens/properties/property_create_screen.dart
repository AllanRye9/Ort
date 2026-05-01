import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/listing_providers.dart';
import '../../core/location_service.dart';
import '../../widgets/media_picker_field.dart';

class PropertyCreateScreen extends ConsumerStatefulWidget {
  const PropertyCreateScreen({super.key});

  @override
  ConsumerState<PropertyCreateScreen> createState() =>
      _PropertyCreateScreenState();
}

class _PropertyCreateScreenState extends ConsumerState<PropertyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _placeNameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _bedroomsCtrl = TextEditingController();
  final _bathroomsCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _landAreaCtrl = TextEditingController();

  String _propertyType = 'house';
  List<String> _imageUrls = [];
  bool _submitting = false;

  // Land category fields
  String? _landCategory;     // farmland, residential, industrial, other
  String _landAreaUnit = 'acres'; // acres or hectares
  bool _landResidentialUseMetric = false; // use L×W in meters for residential land

  static const _landCategories = ['farmland', 'residential', 'industrial', 'other'];

  // Location state
  double? _geocodedLat;
  double? _geocodedLon;
  String? _geocodedCountry;
  String? _geocodedDisplayName;
  bool _geocoding = false;
  bool _gpsCapturing = false;
  String? _locationError;

  bool get _isUganda => _geocodedCountry?.toLowerCase() == 'uganda';
  bool get _isUAE =>
      _geocodedCountry?.toLowerCase() == 'united arab emirates';

  // Property types that have bedrooms / bathrooms
  static const _residentialTypes = ['house', 'apartment', 'villa'];

  bool get _showBedroomsBathrooms =>
      _residentialTypes.contains(_propertyType);

  String get _currencyCode =>
      _isUganda ? 'UGX' : (_isUAE ? 'AED' : 'USD');

  String get _currencyPrefix =>
      _isUganda ? 'UGX ' : (_isUAE ? 'AED ' : '\$');

  static const _propertyTypes = [
    'house',
    'apartment',
    'land',
    'commercial',
    'villa',
    'office',
    'warehouse',
    'other',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _placeNameCtrl.dispose();
    _priceCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _areaCtrl.dispose();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _landAreaCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureGpsLocation() async {
    setState(() {
      _gpsCapturing = true;
      _locationError = null;
    });
    try {
      final pos = await LocationService.instance.requestAndGetPosition();
      if (!mounted) return;
      if (pos == null) {
        setState(() {
          _locationError = 'Location services are off. Please enable GPS in settings.';
          _gpsCapturing = false;
        });
        return;
      }
      // Use Nominatim /reverse endpoint for accurate reverse geocoding.
      final result = await LocationService.instance.reverseGeocodePosition(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _geocodedLat = pos.latitude;
        _geocodedLon = pos.longitude;
        _geocodedCountry = result?.country;
        _geocodedDisplayName = result?.displayName ??
            '${pos.latitude.toStringAsFixed(5)}, '
            '${pos.longitude.toStringAsFixed(5)}';
        _locationError = null;
        _gpsCapturing = false;
      });
    } on LocationPermissionDeniedException {
      if (mounted) {
        setState(() {
          _locationError =
              'Location permission is permanently denied. Open app settings to enable it.';
          _gpsCapturing = false;
        });
        // Offer to open app settings
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'Location permission has been permanently denied. '
              'To use GPS, please open app settings and allow location access.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (open == true) {
          await Geolocator.openAppSettings();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationError = 'GPS capture failed. Please try again.';
          _gpsCapturing = false;
        });
      }
    }
  }

  Future<void> _validatePlaceName() async {
    final query = _placeNameCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _geocoding = true;
      _locationError = null;
      _geocodedLat = null;
      _geocodedLon = null;
      _geocodedCountry = null;
      _geocodedDisplayName = null;
    });
    try {
      final result =
          await LocationService.instance.geocodeAddressDetailed(query);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _locationError =
              "Place doesn't exist on Map. Please correct the spelling "
              'or use a more recognised landmark.';
          _geocoding = false;
        });
        return;
      }
      setState(() {
        _geocodedLat = result.latitude;
        _geocodedLon = result.longitude;
        _geocodedCountry = result.country;
        _geocodedDisplayName = result.displayName;
        _locationError = null;
        _geocoding = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationError =
              'Map service is unreachable. Please check your connection.';
          _geocoding = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_geocodedLat == null || _geocodedLon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please validate the listing location before publishing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      double? areaValue;
      double? lengthM;
      double? widthM;
      double? landAreaAcres;

      final isLand = _propertyType == 'land';

      if (isLand && _landCategory != null) {
        // Collect land area
        if (_landCategory == 'residential' && _landResidentialUseMetric) {
          // Use L×W in meters
          final l = double.tryParse(_lengthCtrl.text.trim());
          final w = double.tryParse(_widthCtrl.text.trim());
          if (l != null && w != null) {
            lengthM = l;
            widthM = w;
          }
        } else {
          // Use acres or hectares input
          // Area conversion: 1 hectare = 2.47105 acres
          const double hectaresToAcres = 2.47105;
          final val = double.tryParse(_landAreaCtrl.text.trim());
          if (val != null) {
            landAreaAcres = _landAreaUnit == 'hectares' ? val * hectaresToAcres : val;
          }
        }
      } else if (_isUganda) {
        final l = double.tryParse(_lengthCtrl.text.trim());
        final w = double.tryParse(_widthCtrl.text.trim());
        if (l != null && w != null) {
          lengthM = l;
          widthM = w;
        }
      } else {
        areaValue = _areaCtrl.text.trim().isNotEmpty
            ? double.tryParse(_areaCtrl.text.trim())
            : null;
      }

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isNotEmpty
            ? _addressCtrl.text.trim()
            : (_geocodedDisplayName ?? 'Unknown'),
        'price': double.parse(_priceCtrl.text.trim()),
        'property_type': _propertyType,
        'latitude': _geocodedLat,
        'longitude': _geocodedLon,
        if (_geocodedCountry != null) 'country': _geocodedCountry,
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_cityCtrl.text.trim().isNotEmpty) 'city': _cityCtrl.text.trim(),
        if (!isLand && _bedroomsCtrl.text.trim().isNotEmpty)
          'bedrooms': int.parse(_bedroomsCtrl.text.trim()),
        if (!isLand && _bathroomsCtrl.text.trim().isNotEmpty)
          'bathrooms': int.parse(_bathroomsCtrl.text.trim()),
        if (!isLand && !_isUganda && areaValue != null)
          'area_sqft': areaValue.toInt(),
        if (!isLand && _isUganda && lengthM != null) 'plot_length_m': lengthM,
        if (!isLand && _isUganda && widthM != null) 'plot_width_m': widthM,
        if (isLand && _landCategory != null) 'land_category': _landCategory,
        if (isLand && landAreaAcres != null) 'land_area_acres': landAreaAcres,
        if (isLand && lengthM != null) 'plot_length_m': lengthM,
        if (isLand && widthM != null) 'plot_width_m': widthM,
        if (_imageUrls.isNotEmpty) 'images': _imageUrls,
      };

      await ref.read(apiServiceProvider).createProperty(payload);
      invalidateHomeProviders(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property listed successfully!')),
        );
        context.go('/properties');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create listing: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('List a Property')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photos ─────────────────────────────────────────────────────
              _sectionTitle('PHOTOS'),
              MediaPickerField(
                label: 'Property Photos',
                maxImages: 8,
                onUrlsChanged: (urls) => _imageUrls = urls,
              ),

              // ── Basic Info ─────────────────────────────────────────────────
              _sectionTitle('BASIC INFORMATION'),
              TextFormField(
                controller: _titleCtrl,
                decoration:
                    const InputDecoration(labelText: 'Property Title *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _propertyType,
                decoration:
                    const InputDecoration(labelText: 'Property Type *'),
                items: _propertyTypes
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                            t[0].toUpperCase() + t.substring(1))))
                    .toList(),
                onChanged: (v) => setState(() {
                    _propertyType = v!;
                    // Reset land-specific fields when switching away from land
                    if (v != 'land') {
                      _landCategory = null;
                    }
                  }),
              ),
              // ── Land category (shown only when property_type == 'land') ────
              if (_propertyType == 'land') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _landCategory,
                  decoration: const InputDecoration(
                    labelText: 'Land Category *',
                  ),
                  items: _landCategories
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                              c[0].toUpperCase() + c.substring(1))))
                      .toList(),
                  onChanged: (v) => setState(() => _landCategory = v),
                  validator: (v) =>
                      v == null ? 'Please select a land category' : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 3,
              ),

              // ── Location ────────────────────────────────────────────────────
              _sectionTitle('LOCATION'),
              Text(
                'Option A – Use my current GPS location',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: _gpsCapturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(_gpsCapturing
                    ? 'Getting location…'
                    : 'Capture GPS Location'),
                onPressed:
                    (_gpsCapturing || _geocoding) ? null : _captureGpsLocation,
              ),
              const SizedBox(height: 16),
              Text(
                'Option B – Enter place name',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _placeNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Place name (e.g. "Mbarara, Uganda")',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton(
                      onPressed:
                          (_geocoding || _gpsCapturing) ? null : _validatePlaceName,
                      child: _geocoding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Validate'),
                    ),
                  ),
                ],
              ),
              // Show validation result / error
              if (_geocodedDisplayName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: cs.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _geocodedDisplayName!,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.8)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isUganda)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Chip(
                            label: const Text('Uganda',
                                style: TextStyle(fontSize: 10)),
                            backgroundColor:
                                cs.secondary.withValues(alpha: 0.15),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (_locationError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: cs.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: TextStyle(
                            fontSize: 12, color: cs.error),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                    labelText: 'Street address (optional refinement)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityCtrl,
                decoration:
                    const InputDecoration(labelText: 'City (optional)'),
              ),

              // ── Pricing ─────────────────────────────────────────────────────
              _sectionTitle('PRICING'),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price ($_currencyCode) *',
                  prefixText: _currencyPrefix,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),

              // ── Details ──────────────────────────────────────────────────────
              _sectionTitle('DETAILS'),
              if (_propertyType == 'land' && _landCategory != null) ...[
                // Land area measurement section
                _LandAreaSection(
                  landCategory: _landCategory!,
                  landAreaUnit: _landAreaUnit,
                  landAreaCtrl: _landAreaCtrl,
                  lengthCtrl: _lengthCtrl,
                  widthCtrl: _widthCtrl,
                  residentialUseMetric: _landResidentialUseMetric,
                  onUnitChanged: (u) => setState(() => _landAreaUnit = u),
                  onMetricChanged: (v) =>
                      setState(() => _landResidentialUseMetric = v),
                  onChanged: () => setState(() {}),
                  cs: cs,
                ),
              ] else if (_propertyType != 'land') ...[
                // Bedrooms/bathrooms only for residential types
                if (_showBedroomsBathrooms) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _bedroomsCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Bedrooms'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (int.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _bathroomsCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Bathrooms'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (int.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // Uganda: L × W measurement; everywhere else: area in sqft
                if (_isUganda) ...[
                  Text(
                    'PLOT DIMENSIONS (METRIC – UGANDA)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lengthCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Length (m)', suffixText: 'm'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _widthCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Width (m)', suffixText: 'm'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  Builder(builder: (_) {
                    final l = double.tryParse(_lengthCtrl.text);
                    final w = double.tryParse(_widthCtrl.text);
                    if (l != null && w != null) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Dimensions: ${l.toStringAsFixed(0)}m × '
                          '${w.toStringAsFixed(0)}m  |  '
                          'Total Area: ${(l * w).toStringAsFixed(0)} m²',
                          style: TextStyle(
                              fontSize: 13,
                              color: cs.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ] else ...[
                  TextFormField(
                    controller: _areaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Area (sqft, optional)'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (int.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ],
              ],

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Publish Listing'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Land area section widget ────────────────────────────────────────────────

class _LandAreaSection extends StatelessWidget {
  const _LandAreaSection({
    required this.landCategory,
    required this.landAreaUnit,
    required this.landAreaCtrl,
    required this.lengthCtrl,
    required this.widthCtrl,
    required this.residentialUseMetric,
    required this.onUnitChanged,
    required this.onMetricChanged,
    required this.onChanged,
    required this.cs,
  });

  final String landCategory;
  final String landAreaUnit;
  final TextEditingController landAreaCtrl;
  final TextEditingController lengthCtrl;
  final TextEditingController widthCtrl;
  final bool residentialUseMetric;
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<bool> onMetricChanged;
  final VoidCallback onChanged;
  final ColorScheme cs;

  double get _minAcres => landAreaUnit == 'hectares' ? 0.1 : 1.0;
  String get _minLabel => landAreaUnit == 'hectares' ? '0.1 ha' : '1 acre';

  @override
  Widget build(BuildContext context) {
    // Residential land can use L×W in meters OR acres/hectares
    if (landCategory == 'residential') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Measurement mode:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('L × W (m)', style: TextStyle(fontSize: 12)),
                selected: residentialUseMetric,
                onSelected: (_) => onMetricChanged(true),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Acres/Hectares',
                    style: TextStyle(fontSize: 12)),
                selected: !residentialUseMetric,
                onSelected: (_) => onMetricChanged(false),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (residentialUseMetric)
            _MetricDimensionsInput(
                lengthCtrl: lengthCtrl,
                widthCtrl: widthCtrl,
                cs: cs,
                onChanged: onChanged)
          else
            _AcresHectaresInput(
              ctrl: landAreaCtrl,
              unit: landAreaUnit,
              minValue: _minAcres,
              minLabel: _minLabel,
              onUnitChanged: onUnitChanged,
            ),
        ],
      );
    }

    // Farmland / Industrial / Other → acres / hectares
    return _AcresHectaresInput(
      ctrl: landAreaCtrl,
      unit: landAreaUnit,
      minValue: _minAcres,
      minLabel: _minLabel,
      onUnitChanged: onUnitChanged,
      isFarmland: landCategory == 'farmland',
    );
  }
}

class _AcresHectaresInput extends StatelessWidget {
  const _AcresHectaresInput({
    required this.ctrl,
    required this.unit,
    required this.minValue,
    required this.minLabel,
    required this.onUnitChanged,
    this.isFarmland = false,
  });

  final TextEditingController ctrl;
  final String unit;
  final double minValue;
  final String minLabel;
  final ValueChanged<String> onUnitChanged;
  final bool isFarmland;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Unit:', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            ChoiceChip(
              label:
                  const Text('Acres', style: TextStyle(fontSize: 12)),
              selected: unit == 'acres',
              onSelected: (_) => onUnitChanged('acres'),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('Hectares',
                  style: TextStyle(fontSize: 12)),
              selected: unit == 'hectares',
              onSelected: (_) => onUnitChanged('hectares'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Land Area ($unit) *',
            suffixText: unit == 'acres' ? 'ac' : 'ha',
            helperText: isFarmland
                ? 'Minimum: $minLabel  ·  step: 0.01'
                : 'Minimum: $minLabel',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Area is required';
            final val = double.tryParse(v.trim());
            if (val == null) return 'Enter a valid number';
            if (val < minValue) {
              return 'Minimum $minLabel';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _MetricDimensionsInput extends StatelessWidget {
  const _MetricDimensionsInput({
    required this.lengthCtrl,
    required this.widthCtrl,
    required this.cs,
    required this.onChanged,
  });

  final TextEditingController lengthCtrl;
  final TextEditingController widthCtrl;
  final ColorScheme cs;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: lengthCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Length (m)', suffixText: 'm'),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  if (double.tryParse(v) == null) return 'Invalid';
                  return null;
                },
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: widthCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Width (m)', suffixText: 'm'),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  if (double.tryParse(v) == null) return 'Invalid';
                  return null;
                },
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        Builder(builder: (_) {
          final l = double.tryParse(lengthCtrl.text);
          final w = double.tryParse(widthCtrl.text);
          if (l != null && w != null) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${l.toStringAsFixed(0)}m × ${w.toStringAsFixed(0)}m  |  '
                '${(l * w).toStringAsFixed(0)} m²',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.primary,
                    fontWeight: FontWeight.w600),
              ),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }
}
