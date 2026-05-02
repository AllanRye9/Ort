import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/listing_providers.dart';
import '../../core/location_service.dart';
import '../../models/models.dart';
import '../../widgets/media_picker_field.dart';

class AgricultureEditScreen extends ConsumerStatefulWidget {
  const AgricultureEditScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<AgricultureEditScreen> createState() =>
      _AgricultureEditScreenState();
}

class _AgricultureEditScreenState
    extends ConsumerState<AgricultureEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _moqCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _certCtrl = TextEditingController();
  final _storageCtrl = TextEditingController();
  final _placeNameCtrl = TextEditingController();

  String _category = 'grains';
  bool _isPerishable = false;
  List<String> _imageUrls = [];
  bool _submitting = false;
  bool _loading = true;
  AgricultureListingModel? _original;

  // Location state
  double? _geocodedLat;
  double? _geocodedLon;
  String? _geocodedDisplayName;
  bool _geocoding = false;
  bool _gpsCapturing = false;
  String? _locationError;

  static const _categories = [
    'grains',
    'vegetables',
    'fruits',
    'livestock',
    'dairy',
    'poultry',
    'fish',
    'spices',
    'oil_seeds',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  Future<void> _loadListing() async {
    try {
      final data =
          await ref.read(apiServiceProvider).getAgricultureListing(widget.id);
      final m = AgricultureListingModel.fromJson(data);
      setState(() {
        _original = m;
        _titleCtrl.text = m.title;
        _descCtrl.text = m.description ?? '';
        _locationCtrl.text = m.location ?? '';
        _priceCtrl.text = m.pricePerUnit.toStringAsFixed(2);
        _unitCtrl.text = m.unit ?? '';
        _moqCtrl.text = m.moq?.toStringAsFixed(2) ?? '';
        _qtyCtrl.text =
            m.quantityAvailable?.toStringAsFixed(2) ?? '';
        _gradeCtrl.text = m.qualityGrade ?? '';
        _certCtrl.text = m.certification ?? '';
        _storageCtrl.text = m.storageConditions ?? '';
        _category = _categories.contains(m.category) ? m.category! : 'grains';
        _isPerishable = m.isPerishable;
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
          SnackBar(content: Text('Failed to load listing: $e')),
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
    _moqCtrl.dispose();
    _qtyCtrl.dispose();
    _gradeCtrl.dispose();
    _certCtrl.dispose();
    _storageCtrl.dispose();
    _placeNameCtrl.dispose();
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
    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'price_per_unit': double.parse(_priceCtrl.text.trim()),
        'category': _category,
        'is_perishable': _isPerishable,
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_locationCtrl.text.trim().isNotEmpty)
          'location': _locationCtrl.text.trim(),
        if (_geocodedLat != null) 'latitude': _geocodedLat,
        if (_geocodedLon != null) 'longitude': _geocodedLon,
        if (_unitCtrl.text.trim().isNotEmpty) 'unit': _unitCtrl.text.trim(),
        if (_moqCtrl.text.trim().isNotEmpty)
          'moq': double.parse(_moqCtrl.text.trim()),
        if (_qtyCtrl.text.trim().isNotEmpty)
          'quantity_available': double.parse(_qtyCtrl.text.trim()),
        if (_gradeCtrl.text.trim().isNotEmpty)
          'quality_grade': _gradeCtrl.text.trim(),
        if (_certCtrl.text.trim().isNotEmpty)
          'certification': _certCtrl.text.trim(),
        if (_storageCtrl.text.trim().isNotEmpty)
          'storage_conditions': _storageCtrl.text.trim(),
        if (_imageUrls.isNotEmpty) 'images': _imageUrls,
      };

      await ref
          .read(apiServiceProvider)
          .updateAgricultureListing(widget.id, payload);
      invalidateHomeProviders(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated successfully!')),
        );
        context.go('/my-listings');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update listing: $e')),
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
        appBar: AppBar(title: const Text('Edit Agriculture Listing')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Agriculture Listing')),
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
                    const InputDecoration(labelText: 'Product / Commodity Title *'),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isPerishable,
                onChanged: (v) => setState(() => _isPerishable = v),
                title: const Text('Perishable product'),
                subtitle: const Text(
                    'Requires special handling or has a short shelf life'),
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
                decoration:
                    const InputDecoration(labelText: 'Location / Farm Address (optional)'),
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
                        labelText: 'Price per Unit *',
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
                      decoration: const InputDecoration(
                          labelText: 'Unit (e.g. kg, ton)'),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Min. Order Qty'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _qtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Available Qty'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              _sectionTitle('QUALITY & CERTIFICATIONS'),
              TextFormField(
                controller: _gradeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Quality Grade (e.g. Grade A, Premium)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _certCtrl,
                decoration: const InputDecoration(
                    labelText: 'Certification (e.g. Organic, USDA)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _storageCtrl,
                decoration:
                    const InputDecoration(labelText: 'Storage Conditions'),
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
