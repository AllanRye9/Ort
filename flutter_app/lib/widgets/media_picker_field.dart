import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_service.dart';

/// A form field that lets the user pick images from the gallery / camera,
/// uploads them via the API and exposes the resulting public URLs.
class MediaPickerField extends ConsumerStatefulWidget {
  const MediaPickerField({
    super.key,
    required this.onUrlsChanged,
    this.initialUrls = const [],
    this.maxImages = 5,
    this.label = 'Photos',
  });

  final ValueChanged<List<String>> onUrlsChanged;
  final List<String> initialUrls;
  final int maxImages;
  final String label;

  @override
  ConsumerState<MediaPickerField> createState() => _MediaPickerFieldState();
}

class _MediaPickerFieldState extends ConsumerState<MediaPickerField> {
  final _picker = ImagePicker();
  final List<String> _urls = [];
  final List<bool> _uploading = [];

  @override
  void initState() {
    super.initState();
    _urls.addAll(widget.initialUrls);
  }

  bool get _canAddMore => _urls.length + _uploadingCount < widget.maxImages;
  int get _uploadingCount => _uploading.where((v) => v).length;

  Future<void> _pickImage(ImageSource source) async {
    if (!_canAddMore) return;
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    final filename = file.name;
    final ext = filename.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    final idx = _urls.length;
    setState(() {
      _urls.add('');
      _uploading.add(true);
    });

    try {
      final url = await ref.read(apiServiceProvider).uploadImage(
            bytes: bytes,
            filename: filename,
            mimeType: mimeType,
          );
      if (mounted) {
        setState(() {
          _urls[idx] = url;
          _uploading[idx] = false;
        });
        widget.onUrlsChanged(List.unmodifiable(_urls.where((u) => u.isNotEmpty)));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _urls.removeAt(idx);
          _uploading.removeAt(idx);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  void _remove(int index) {
    setState(() {
      _urls.removeAt(index);
      _uploading.removeAt(index);
    });
    widget.onUrlsChanged(List.unmodifiable(_urls.where((u) => u.isNotEmpty)));
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Add Photo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${_urls.length}/${widget.maxImages})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Existing / uploading images
              ...List.generate(_urls.length, (i) {
                final uploading = i < _uploading.length && _uploading[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: uploading
                            ? Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[200],
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              )
                            : Image.network(
                                _urls[i],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                              ),
                      ),
                      if (!uploading)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _remove(i),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              // Add button
              if (_canAddMore)
                GestureDetector(
                  onTap: _showSourcePicker,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add photo',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
