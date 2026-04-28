import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/listing_providers.dart';
import '../../widgets/media_picker_field.dart';

class AgricultureCreateScreen extends ConsumerStatefulWidget {
  const AgricultureCreateScreen({super.key});

  @override
  ConsumerState<AgricultureCreateScreen> createState() =>
      _AgricultureCreateScreenState();
}

class _AgricultureCreateScreenState
    extends ConsumerState<AgricultureCreateScreen> {
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

  String _category = 'grains';
  bool _isPerishable = false;
  List<String> _imageUrls = [];
  bool _submitting = false;

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
    super.dispose();
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

      await ref.read(apiServiceProvider).createAgricultureListing(payload);
      invalidateHomeProviders(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing created successfully!')),
        );
        context.go('/agriculture');
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
      appBar: AppBar(title: const Text('Add Agriculture Listing')),
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
                        labelText: 'Price per Unit (USD) *',
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
