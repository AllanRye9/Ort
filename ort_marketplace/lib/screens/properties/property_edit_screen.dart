import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/app_preferences.dart';
import '../../core/listing_providers.dart';
import '../../core/location_service.dart';
import '../../models/models.dart';
import '../../widgets/media_picker_field.dart';
import '../properties/property_create_screen.dart'
    show LandAreaSection, MetricDimensionsInput;

class PropertyEditScreen extends ConsumerStatefulWidget {
  const PropertyEditScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<PropertyEditScreen> createState() =>
      _PropertyEditScreenState();
}

class _PropertyEditScreenState extends ConsumerState<PropertyEditScreen> {
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
  final _customPropertyTypeCtrl = TextEditingController();
  List<String> _imageUrls = [];
  bool _submitting = false;
  bool _loading = true;

  // Land category fields
  String? _landCategory;
  String _landAreaUnit = 'acres';
  bool _landResidentialUseMetric = false;

  static const _landCategories = ['farmland', 'residential', 'industrial', 'other'];

  // Location state
  double? _geocodedLat;
  double? _geocodedLon;
  String? _geocodedCountry;
  String? _geocodedDisplayName;
  bool _geocoding = false;
  bool _gpsCapturing = false;
  String? _locationError;

  bool get _isUganda => matchesCountry(_geocodedCountry, 'Uganda');
  bool get _isUAE => matchesCountry(_geocodedCountry, 'United Arab Emirates');

  static const _residentialTypes = ['house', 'apartment', 'villa'];

  bool get _showBedroomsBathrooms =>
      _residentialTypes.contains(_propertyType);

  String get _priceCurrencyCode {
    final mode = ref.read(marketplaceModeProvider);
    if (mode == MarketplaceMode.international) return 'USD';
    if (_isUganda) return 'UGX';
    if (_isUAE) return 'AED';
    return 'USD';
  }

  String get _priceCurrencyPrefix {
    final mode = ref.read(marketplaceModeProvider);
    if (mode == MarketplaceMode.international) return '\$';
    if (_isUganda) return 'UGX ';
    if (_isUAE) return 'AED ';
    return '\$';
  }

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
  void initState() {
    super.initState();
    _loadProperty();
  }

  Future<void> _loadProperty() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getProperty(widget.id);
      final p = PropertyModel.fromJson(data);

      setState(() {
        _titleCtrl.text = p.title;
        _descCtrl.text = p.description ?? '';
        _addressCtrl.text = p.address;
        _cityCtrl.text = p.city ?? '';
        _priceCtrl.text = p.price.toStringAsFixed(0);
        _bedroomsCtrl.text = p.bedrooms?.toString() ?? '';
        _bathroomsCtrl.text = p.bathrooms?.toString() ?? '';
        _areaCtrl.text = p.areaSqft?.toString() ?? '';
        _lengthCtrl.text = p.plotLengthM?.toStringAsFixed(0) ?? '';
        _widthCtrl.text = p.plotWidthM?.toStringAsFixed(0) ?? '';
        _landAreaCtrl.text = p.landAreaAcres?.toStringAsFixed(2) ?? '';
        _propertyType =
            _propertyTypes.contains(p.propertyType) ? p.propertyType : 'other';
        if (!_propertyTypes.contains(p.propertyType) && p.propertyType.isNotEmpty) {
          _customPropertyTypeCtrl.text = p.propertyType;
        }
        _landCategory = p.landCategory;
        _imageUrls = List<String>.from(p.imageUrls);
        _geocodedLat = p.latitude;
        _geocodedLon = p.longitude;
        _geocodedCountry = p.country;
        if (p.latitude != null && p.longitude != null) {
          _geocodedDisplayName =
              '${p.latitude!.toStringAsFixed(5)}, ${p.longitude!.toStringAsFixed(5)}';
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load property: $e')),
        );
      }
    }
  }

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
    _customPropertyTypeCtrl.dispose();
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
          _locationError =
              'Location unavailable. Check that GPS is enabled and permissions are granted.';
          _gpsCapturing = false;
        });
        return;
      }
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
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
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
    setState(() => _submitting = true);
    try {
      double? areaValue;
      double? lengthM;
      double? widthM;
      double? landAreaAcres;

      final effectivePropertyType = _propertyType == 'other'
          ? _customPropertyTypeCtrl.text.trim().toLowerCase().replaceAll(' ', '_')
          : _propertyType;
      final isLand = effectivePropertyType == 'land';

      if (isLand && _landCategory != null) {
        if (_landCategory == 'residential' && _landResidentialUseMetric) {
          final l = double.tryParse(_lengthCtrl.text.trim());
          final w = double.tryParse(_widthCtrl.text.trim());
          if (l != null && w != null) {
            lengthM = l;
            widthM = w;
          }
        } else {
          const double hectaresToAcres = 2.47105;
          final val = double.tryParse(_landAreaCtrl.text.trim());
          if (val != null) {
            landAreaAcres =
                _landAreaUnit == 'hectares' ? val * hectaresToAcres : val;
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
        'property_type': effectivePropertyType,
        if (_geocodedLat != null) 'latitude': _geocodedLat,
        if (_geocodedLon != null) 'longitude': _geocodedLon,
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

      await ref.read(apiServiceProvider).updateProperty(widget.id, payload);
      invalidateHomeProviders(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property updated successfully!')),
        );
        context.go('/my-listings');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update property: $e')),
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Property')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Property')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photos ────────────────────────────────────────────────────
              _sectionTitle('PHOTOS'),
              MediaPickerField(
                label: 'Property Photos',
                maxImages: 8,
                initialUrls: _imageUrls,
                onUrlsChanged: (urls) => setState(() => _imageUrls = urls),
              ),

              // ── Basic Info ────────────────────────────────────────────────
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
                        child: Text(t[0].toUpperCase() + t.substring(1))))
                    .toList(),
                onChanged: (v) => setState(() {
                  _propertyType = v!;
                  if (v != 'land') _landCategory = null;
                }),
              ),
              if (_propertyType == 'other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customPropertyTypeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custom Property Type *',
                    hintText: 'e.g. Guesthouse, Resort, Hostel',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ],
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
                          child:
                              Text(c[0].toUpperCase() + c.substring(1))))
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

              // ── Location ──────────────────────────────────────────────────
              _sectionTitle('LOCATION'),
              if (_geocodedDisplayName != null) ...[
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
                      Icon(Icons.location_on, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Current: $_geocodedDisplayName',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.8)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                'Update location (optional)',
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
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _placeNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Or enter place name',
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
              if (_locationError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: cs.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: TextStyle(fontSize: 12, color: cs.error),
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

              // ── Pricing ───────────────────────────────────────────────────
              _sectionTitle('PRICING'),
              TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price ($_priceCurrencyCode) *',
                  prefixText: _priceCurrencyPrefix,
                  helperText: _isUganda
                      ? 'Enter price in Uganda Shillings (UGX)'
                      : _isUAE
                          ? 'Enter price in UAE Dirhams (AED)'
                          : null,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),

              // ── Details ───────────────────────────────────────────────────
              _sectionTitle('DETAILS'),
              if (_propertyType == 'land' && _landCategory != null) ...[
                LandAreaSection(
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
                  MetricDimensionsInput(
                    lengthCtrl: _lengthCtrl,
                    widthCtrl: _widthCtrl,
                    cs: cs,
                    onChanged: () => setState(() {}),
                  ),
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
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update Listing'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
