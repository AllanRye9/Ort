import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/listing_providers.dart';
import '../../core/location_service.dart';
import '../../models/models.dart';
import '../../widgets/media_picker_field.dart';

class ManufacturingEditScreen extends ConsumerStatefulWidget {
  const ManufacturingEditScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<ManufacturingEditScreen> createState() =>
      _ManufacturingEditScreenState();
}

class _ManufacturingEditScreenState
    extends ConsumerState<ManufacturingEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _moqCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _leadTimeCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _certCtrl = TextEditingController();
  final _placeNameCtrl = TextEditingController();
  final _customCategoryCtrl = TextEditingController();

  String _category = 'textiles';
  bool _isLocallyMade = false;
  List<String> _imageUrls = [];
  bool _submitting = false;
  bool _loading = true;

  // Location state
  double? _geocodedLat;
  double? _geocodedLon;
  String? _geocodedDisplayName;
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

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final data =
          await ref.read(apiServiceProvider).getManufacturingProduct(widget.id);
      final m = ManufacturingProductModel.fromJson(data);
      setState(() {
        _titleCtrl.text = m.title;
        _descCtrl.text = m.description ?? '';
        _locationCtrl.text = m.location ?? '';
        _priceCtrl.text = m.wholesalePrice.toStringAsFixed(2);
        _unitCtrl.text = m.unit ?? '';
        _skuCtrl.text = m.sku ?? '';
        _moqCtrl.text = m.moq?.toString() ?? '';
        _qtyCtrl.text = m.quantityAvailable?.toString() ?? '';
        _leadTimeCtrl.text = m.leadTimeDays?.toString() ?? '';
        _countryCtrl.text = m.countryOfOrigin ?? '';
        _certCtrl.text = m.certifications?.join(', ') ?? '';
        _category =
            _categories.contains(m.category) ? m.category! : 'other';
        if (!_categories.contains(m.category) && m.category != null) {
          _customCategoryCtrl.text = m.category!;
        }
        _isLocallyMade = m.isLocallyMade;
        _imageUrls = m.images?.toList() ?? [];
        _geocodedLat = m.latitude;
        _geocodedLon = m.longitude;
        if (m.location != null) {
          _geocodedDisplayName = m.location;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load product: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    _skuCtrl.dispose();
    _moqCtrl.dispose();
    _qtyCtrl.dispose();
    _leadTimeCtrl.dispose();
    _countryCtrl.dispose();
    _certCtrl.dispose();
    _placeNameCtrl.dispose();
    _customCategoryCtrl.dispose();
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
    final effectiveCategory = _category == 'other'
        ? _customCategoryCtrl.text.trim().toLowerCase().replaceAll(' ', '_')
        : _category;
    if (effectiveCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a custom category name.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final certs = _certCtrl.text
          .trim()
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'wholesale_price': double.parse(_priceCtrl.text.trim()),
        'category': effectiveCategory,
        'is_locally_made': _isLocallyMade,
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_locationCtrl.text.trim().isNotEmpty)
          'location': _locationCtrl.text.trim(),
        if (_geocodedLat != null) 'latitude': _geocodedLat,
        if (_geocodedLon != null) 'longitude': _geocodedLon,
        if (_unitCtrl.text.trim().isNotEmpty) 'unit': _unitCtrl.text.trim(),
        if (_skuCtrl.text.trim().isNotEmpty) 'sku': _skuCtrl.text.trim(),
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
      };

      await ref
          .read(apiServiceProvider)
          .updateManufacturingProduct(widget.id, payload);
      invalidateHomeProviders(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully!')),
        );
        context.go('/my-listings');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update product: $e')),
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
        appBar: AppBar(title: const Text('Edit Product')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Product / Goods')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('PHOTOS'),
              MediaPickerField(
                label: 'Product Photos',
                maxImages: 6,
                initialUrls: _imageUrls,
                onUrlsChanged: (urls) => setState(() => _imageUrls = urls),
              ),

              _sectionTitle('BASIC INFORMATION'),
              TextFormField(
                controller: _titleCtrl,
                decoration:
                    const InputDecoration(labelText: 'Product Name *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category *'),
                items: _categories
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                            c.replaceAll('_', ' ')[0].toUpperCase() +
                                c.replaceAll('_', ' ').substring(1))))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              if (_category == 'other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customCategoryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custom Category *',
                    hintText: 'e.g. Composite Materials, Smart Devices',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _skuCtrl,
                decoration: const InputDecoration(labelText: 'SKU (optional)'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isLocallyMade,
                onChanged: (v) => setState(() => _isLocallyMade = v),
                title: const Text('Locally manufactured'),
                contentPadding: EdgeInsets.zero,
              ),

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
                    labelText: 'Location / Manufacturer Address (optional)',
                    prefixIcon: Icon(Icons.location_on_outlined)),
              ),

              _sectionTitle('PRICING & UNITS'),
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
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _unitCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Unit (e.g. pcs)'),
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
                      decoration:
                          const InputDecoration(labelText: 'Min. Order Qty'),
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
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Stock Qty'),
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _leadTimeCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Lead Time (days)'),
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
                      controller: _countryCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Country of Origin'),
                    ),
                  ),
                ],
              ),

              _sectionTitle('CERTIFICATIONS'),
              TextFormField(
                controller: _certCtrl,
                decoration: const InputDecoration(
                  labelText: 'Certifications (comma-separated)',
                  hintText: 'ISO 9001, CE, RoHS',
                ),
              ),

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
                      : const Text('Update Product'),
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
