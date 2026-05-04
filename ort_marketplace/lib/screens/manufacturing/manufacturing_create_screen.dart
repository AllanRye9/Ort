import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/listing_providers.dart';
import '../../core/location_service.dart';
import '../../widgets/ai_description_button.dart';
import '../../widgets/media_picker_field.dart';

class ManufacturingCreateScreen extends ConsumerStatefulWidget {
  const ManufacturingCreateScreen({super.key});

  @override
  ConsumerState<ManufacturingCreateScreen> createState() =>
      _ManufacturingCreateScreenState();
}

class _ManufacturingCreateScreenState
    extends ConsumerState<ManufacturingCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Listing type toggle ─────────────────────────────────────────────────
  bool _isService = false;

  // ── Shared fields ────────────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _certCtrl = TextEditingController();
  final _placeNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  List<String> _imageUrls = [];
  bool _submitting = false;

  // ── Product-only fields ──────────────────────────────────────────────────
  final _productCodeCtrl = TextEditingController(); // SKU
  final _unitCtrl = TextEditingController();
  final _moqCtrl = TextEditingController(); // Minimum order quantity
  final _qtyCtrl = TextEditingController(); // Stock available
  final _leadTimeCtrl = TextEditingController(); // Processing time (days)
  final _countryCtrl = TextEditingController();
  String _category = 'textiles';
  bool _isLocallyMade = false;

  // ── Service-only fields ──────────────────────────────────────────────────
  String _serviceType = 'machining';
  String _pricingUnit = 'per_hour';
  final _minOrderCtrl = TextEditingController(); // Min order value
  final _noticePeriodCtrl = TextEditingController(); // Notice period days

  // ── Location state ────────────────────────────────────────────────────────
  double? _geocodedLat;
  double? _geocodedLon;
  String? _geocodedDisplayName;
  String? _geocodedCountry;
  bool _geocoding = false;
  bool _gpsCapturing = false;
  String? _locationError;

  static const _categories = [
    'textiles',
    'electronics',
    'furniture',
    'machinery',
    'chemicals',
    'plastics',
    'metals',
    'automotive',
    'food_processing',
    'other',
  ];

  static const _serviceTypes = [
    'machining',
    'fabrication',
    'welding',
    'assembly',
    'finishing',
    'testing',
    'printing',
    'packaging',
    'consultation',
    'other',
  ];

  static const _pricingUnits = [
    'per_hour',
    'per_day',
    'per_project',
    'per_piece',
    'fixed',
  ];

  static String _labelForPricingUnit(String u) {
    switch (u) {
      case 'per_hour':
        return 'Per hour';
      case 'per_day':
        return 'Per day';
      case 'per_project':
        return 'Per project';
      case 'per_piece':
        return 'Per piece';
      case 'fixed':
        return 'Fixed price';
      default:
        return u;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _certCtrl.dispose();
    _placeNameCtrl.dispose();
    _locationCtrl.dispose();
    _productCodeCtrl.dispose();
    _unitCtrl.dispose();
    _moqCtrl.dispose();
    _qtyCtrl.dispose();
    _leadTimeCtrl.dispose();
    _countryCtrl.dispose();
    _minOrderCtrl.dispose();
    _noticePeriodCtrl.dispose();
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
          _locationError = 'Could not get GPS location. Check permissions.';
          _gpsCapturing = false;
        });
        return;
      }
      setState(() {
        _geocodedLat = pos.latitude;
        _geocodedLon = pos.longitude;
        _geocodedDisplayName =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        _locationError = null;
        _gpsCapturing = false;
      });
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
        _geocodedDisplayName = result.displayName;
        _geocodedCountry = result.country;
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
      final certs = _certCtrl.text
          .trim()
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final userId = ref.read(authProvider).userId;

      if (_isService) {
        final payload = <String, dynamic>{
          'title': _titleCtrl.text.trim(),
          'price': double.parse(_priceCtrl.text.trim()),
          'service_type': _serviceType,
          'pricing_unit': _pricingUnit,
          if (_descCtrl.text.trim().isNotEmpty)
            'description': _descCtrl.text.trim(),
          if (_locationCtrl.text.trim().isNotEmpty)
            'location': _locationCtrl.text.trim(),
          if (_geocodedLat != null) 'latitude': _geocodedLat,
          if (_geocodedLon != null) 'longitude': _geocodedLon,
          if (_geocodedCountry != null) 'country': _geocodedCountry,
          if (_minOrderCtrl.text.trim().isNotEmpty)
            'min_order_value':
                double.parse(_minOrderCtrl.text.trim()),
          if (_noticePeriodCtrl.text.trim().isNotEmpty)
            'notice_period_days':
                int.parse(_noticePeriodCtrl.text.trim()),
          if (certs.isNotEmpty) 'certifications': certs,
          if (_imageUrls.isNotEmpty) 'images': _imageUrls,
          if (userId != null) 'owner_user_id': userId,
        };
        await ref
            .read(apiServiceProvider)
            .createManufacturingService(payload);
      } else {
        final payload = <String, dynamic>{
          'title': _titleCtrl.text.trim(),
          'wholesale_price': double.parse(_priceCtrl.text.trim()),
          'category': _category,
          'is_locally_made': _isLocallyMade,
          if (_descCtrl.text.trim().isNotEmpty)
            'description': _descCtrl.text.trim(),
          if (_locationCtrl.text.trim().isNotEmpty)
            'location': _locationCtrl.text.trim(),
          if (_geocodedLat != null) 'latitude': _geocodedLat,
          if (_geocodedLon != null) 'longitude': _geocodedLon,
          if (_unitCtrl.text.trim().isNotEmpty)
            'unit': _unitCtrl.text.trim(),
          if (_productCodeCtrl.text.trim().isNotEmpty)
            'sku': _productCodeCtrl.text.trim(),
          if (_moqCtrl.text.trim().isNotEmpty)
            'moq': int.parse(_moqCtrl.text.trim()),
          if (_qtyCtrl.text.trim().isNotEmpty)
            'quantity_available': int.parse(_qtyCtrl.text.trim()),
          if (_leadTimeCtrl.text.trim().isNotEmpty)
            'lead_time_days': int.parse(_leadTimeCtrl.text.trim()),
          if (_countryCtrl.text.trim().isNotEmpty)
            'country_of_origin': _countryCtrl.text.trim(),
          if (certs.isNotEmpty) 'certifications': certs,
          if (_imageUrls.isNotEmpty) 'images': _imageUrls,
          if (userId != null) 'owner_user_id': userId,
        };
        await ref
            .read(apiServiceProvider)
            .createManufacturingProduct(payload);
      }

      invalidateHomeProviders(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isService
                    ? 'Service listed successfully!'
                    : 'Product listed successfully!'),
          ),
        );
        context.go('/my-listings');
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

  Widget _locationSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('LOCATION'),
          Text(
            'Option A – Use my current GPS location',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          Text(
            'Option B – Enter place name',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _placeNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Place name (e.g. "Kampala, Uganda")',
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
          if (_geocodedDisplayName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _geocodedDisplayName!,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (_locationError != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.error_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _locationError!,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Full address or area (optional)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
        ],
      );

  Widget _productFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('PRODUCT DETAILS'),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Product Category *'),
            items: _categories
                .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.replaceAll('_', ' ')[0].toUpperCase() +
                        c.replaceAll('_', ' ').substring(1))))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _productCodeCtrl,
            decoration: const InputDecoration(
              labelText: 'Product Code (optional)',
              hintText: 'Your internal reference number',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _isLocallyMade,
            onChanged: (v) => setState(() => _isLocallyMade = v),
            title: const Text('Locally manufactured'),
            contentPadding: EdgeInsets.zero,
          ),
          _sectionTitle('PRICING AND QUANTITY'),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Wholesale Price *',
                    prefixText: '\$',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _unitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Unit (e.g. pieces)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _moqCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Order Quantity (optional)',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (int.tryParse(v) == null) return 'Whole number required';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stock Available (optional)',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (int.tryParse(v) == null) return 'Whole number required';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _leadTimeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Processing Time (days, optional)',
                    hintText: 'How many days to produce/ship',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (int.tryParse(v) == null) return 'Whole number required';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _countryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Country of Origin (optional)',
                  ),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _serviceFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('SERVICE DETAILS'),
          DropdownButtonFormField<String>(
            value: _serviceType,
            decoration: const InputDecoration(labelText: 'Type of Service *'),
            items: _serviceTypes
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t[0].toUpperCase() + t.substring(1))))
                .toList(),
            onChanged: (v) => setState(() => _serviceType = v!),
          ),
          _sectionTitle('PRICING'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    prefixText: '\$',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _pricingUnit,
                  decoration:
                      const InputDecoration(labelText: 'Charged'),
                  items: _pricingUnits
                      .map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(_labelForPricingUnit(u))))
                      .toList(),
                  onChanged: (v) => setState(() => _pricingUnit = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minOrderCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Minimum Job Value (optional)',
                    prefixText: '\$',
                    hintText: 'Smallest project you accept',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _noticePeriodCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Notice Period (days, optional)',
                    hintText: 'Days needed before starting',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (int.tryParse(v) == null) return 'Whole number required';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isService ? 'Add Service' : 'Add Product')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Listing type toggle ──────────────────────────────────
              _sectionTitle('WHAT ARE YOU LISTING?'),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.inventory_2_outlined),
                    label: Text('Product / Goods'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.build_outlined),
                    label: Text('Service'),
                  ),
                ],
                selected: {_isService},
                onSelectionChanged: (s) {
                  setState(() {
                    _isService = s.first;
                    _priceCtrl.clear();
                  });
                },
              ),

              // ── Photos ───────────────────────────────────────────────
              _sectionTitle('PHOTOS'),
              MediaPickerField(
                label: _isService ? 'Service Photos' : 'Product Photos',
                maxImages: 6,
                onUrlsChanged: (urls) => _imageUrls = urls,
              ),

              // ── Basic information ─────────────────────────────────────
              _sectionTitle('BASIC INFORMATION'),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: _isService
                      ? 'Service Name *'
                      : 'Product Name *',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  suffixIcon: AiDescriptionButton(
                    controller: _descCtrl,
                    listingType: _isService
                        ? 'manufacturing_service'
                        : 'manufacturing_product',
                    getTitle: () => _titleCtrl.text,
                    getCategory: () =>
                        _isService ? _serviceType : _category,
                    getLocation: () => _locationCtrl.text,
                  ),
                ),
                maxLines: 3,
              ),

              // ── Type-specific fields ──────────────────────────────────
              if (_isService) _serviceFields() else _productFields(),

              // ── Location ─────────────────────────────────────────────
              _locationSection(),

              // ── Certifications ────────────────────────────────────────
              _sectionTitle('CERTIFICATIONS & QUALIFICATIONS'),
              TextFormField(
                controller: _certCtrl,
                decoration: const InputDecoration(
                  labelText: 'Certifications (comma-separated, optional)',
                  hintText: 'ISO 9001, CE, RoHS',
                ),
              ),

              const SizedBox(height: 32),
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
                      : Text(_isService
                          ? 'Publish Service'
                          : 'Publish Product'),
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
