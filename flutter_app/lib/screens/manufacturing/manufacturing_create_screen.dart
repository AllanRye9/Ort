import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/listing_providers.dart';
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

  String _category = 'textiles';
  bool _isLocallyMade = false;
  List<String> _imageUrls = [];
  bool _submitting = false;

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
    super.dispose();
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

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'wholesale_price': double.parse(_priceCtrl.text.trim()),
        'category': _category,
        'is_locally_made': _isLocallyMade,
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_locationCtrl.text.trim().isNotEmpty)
          'location': _locationCtrl.text.trim(),
        if (_unitCtrl.text.trim().isNotEmpty) 'unit': _unitCtrl.text.trim(),
        if (_skuCtrl.text.trim().isNotEmpty) 'sku': _skuCtrl.text.trim(),
        if (_moqCtrl.text.trim().isNotEmpty)
          'moq': double.parse(_moqCtrl.text.trim()),
        if (_qtyCtrl.text.trim().isNotEmpty)
          'quantity_available': int.parse(_qtyCtrl.text.trim()),
        if (_leadTimeCtrl.text.trim().isNotEmpty)
          'lead_time_days': int.parse(_leadTimeCtrl.text.trim()),
        if (_countryCtrl.text.trim().isNotEmpty)
          'country_of_origin': _countryCtrl.text.trim(),
        if (certs.isNotEmpty) 'certifications': certs,
        if (_imageUrls.isNotEmpty) 'images': _imageUrls,
      };

      await ref.read(apiServiceProvider).createManufacturingProduct(payload);
      invalidateHomeProviders(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product listed successfully!')),
        );
        context.go('/manufacturing');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product / Goods')),
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
                onUrlsChanged: (urls) => _imageUrls = urls,
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
                        labelText: 'Wholesale Price (USD) *',
                        prefixText: '\$',
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Min. Order Qty'),
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
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Publish Product'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
