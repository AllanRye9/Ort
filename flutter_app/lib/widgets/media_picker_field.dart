import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_service.dart';

/// A form field that lets the user pick one or multiple images from the
/// gallery / camera, uploads them via the API and exposes the resulting
/// public URLs.
///
/// Set [allowMultiple] to true to enable multi-select from the gallery.
class MediaPickerField extends ConsumerStatefulWidget {
  const MediaPickerField({
    super.key,
    required this.onUrlsChanged,
    this.initialUrls = const [],
    this.maxImages = 10,
    this.label = 'Photos',
    this.allowMultiple = true,
  });

  final ValueChanged<List<String>> onUrlsChanged;
  final List<String> initialUrls;
  final int maxImages;
  final String label;
  final bool allowMultiple;

  @override
  ConsumerState<MediaPickerField> createState() => _MediaPickerFieldState();
}

class _MediaPickerFieldState extends ConsumerState<MediaPickerField> {
  final _picker = ImagePicker();
  final List<String> _urls = [];
  final List<bool> _uploading = [];
  // Local image bytes kept for each slot so a preview is visible while uploading.
  final List<Uint8List?> _localBytes = [];

  static String _mimeTypeFromFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  @override
  void initState() {
    super.initState();
    _urls.addAll(widget.initialUrls);
    _uploading.addAll(List.filled(widget.initialUrls.length, false));
    _localBytes.addAll(List.filled(widget.initialUrls.length, null));
  }

  int get _uploadingCount => _uploading.where((v) => v).length;
  int get _remaining => widget.maxImages - _urls.length - _uploadingCount;
  bool get _canAddMore => _remaining > 0;

  Future<void> _pickMultiple() async {
    if (!_canAddMore) return;
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked.isEmpty || !mounted) return;

    // Limit to remaining slots, inform user if excess were dropped
    final toUpload = picked.take(_remaining).toList();
    if (picked.length > _remaining && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Only $_remaining image${_remaining == 1 ? '' : 's'} can be added. '
              'The first $_remaining were selected.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Read bytes for all picked files up-front so local previews are available
    // immediately while uploads are in progress. Files that cannot be read are
    // silently skipped (e.g. permission denied on some platforms).
    final fileDataList = <({XFile file, Uint8List bytes})>[];
    final unreadable = <int>[];
    final rawReads = await Future.wait(
      toUpload.asMap().entries.map((e) async {
        try {
          final bytes = await e.value.readAsBytes();
          return (idx: e.key, file: e.value, bytes: bytes, ok: true);
        } catch (_) {
          return (idx: e.key, file: e.value, bytes: Uint8List(0), ok: false);
        }
      }),
    );
    for (final r in rawReads) {
      if (r.ok) {
        fileDataList.add((file: r.file, bytes: r.bytes));
      } else {
        unreadable.add(r.idx);
      }
    }
    if (unreadable.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${unreadable.length} image${unreadable.length == 1 ? '' : 's'} could not be read and were skipped.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    if (fileDataList.isEmpty || !mounted) return;

    // Add placeholder slots with local byte previews
    final startIdx = _urls.length;
    setState(() {
      for (final fd in fileDataList) {
        _urls.add('');
        _uploading.add(true);
        _localBytes.add(fd.bytes);
      }
    });

    // Upload concurrently; track failed indices to remove after all complete
    final failedIndices = <int>[];

    await Future.wait(
      List.generate(fileDataList.length, (i) async {
        final fd = fileDataList[i];
        try {
          final filename = fd.file.name;
          final mimeType = _mimeTypeFromFilename(filename);
          final url = await ref.read(apiServiceProvider).uploadImage(
                bytes: fd.bytes,
                filename: filename,
                mimeType: mimeType,
              );
          if (mounted) {
            setState(() {
              _urls[startIdx + i] = url;
              _uploading[startIdx + i] = false;
              // Clear local bytes once the remote URL is available.
              _localBytes[startIdx + i] = null;
            });
          }
        } catch (e) {
          // Mark as failed – will be removed after all futures finish
          failedIndices.add(startIdx + i);
        }
      }),
    );

    // Remove all failed slots in reverse order to keep indices valid
    if (failedIndices.isNotEmpty && mounted) {
      setState(() {
        for (final idx in failedIndices.reversed) {
          _urls.removeAt(idx);
          _uploading.removeAt(idx);
          _localBytes.removeAt(idx);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${failedIndices.length} upload${failedIndices.length == 1 ? '' : 's'} failed.')),
      );
    }
    _notifyChange();
  }

  Future<void> _pickSingle(ImageSource source) async {
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
    final mimeType = _mimeTypeFromFilename(filename);

    final idx = _urls.length;
    setState(() {
      _urls.add('');
      _uploading.add(true);
      _localBytes.add(bytes);
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
          _localBytes[idx] = null;
        });
        _notifyChange();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _urls.removeAt(idx);
          _uploading.removeAt(idx);
          _localBytes.removeAt(idx);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  void _notifyChange() {
    widget.onUrlsChanged(
        List.unmodifiable(_urls.where((u) => u.isNotEmpty)));
  }

  void _remove(int index) {
    final url = index < _urls.length ? _urls[index] : '';
    setState(() {
      _urls.removeAt(index);
      _uploading.removeAt(index);
      _localBytes.removeAt(index);
    });
    _notifyChange();
    // Best-effort: delete from backend if the image was already uploaded.
    if (url.isNotEmpty) {
      ref.read(apiServiceProvider).deleteImage(url).catchError((_) {});
    }
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
              if (widget.allowMultiple)
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose multiple from gallery'),
                  subtitle: Text('Up to $_remaining more'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickMultiple();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Choose one from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickSingle(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickSingle(ImageSource.camera);
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
              '(${_urls.where((u) => u.isNotEmpty).length}/${widget.maxImages})',
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
                final localPreview = _localBytes[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: uploading
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (localPreview != null)
                                    Image.memory(
                                      localPreview,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    )
                                  else
                                    Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[200],
                                    ),
                                  Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.black26,
                                  ),
                                  const CircularProgressIndicator(),
                                ],
                              )
                            : CachedNetworkImage(
                                imageUrl: _urls[i],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
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
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.4),
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
                          widget.allowMultiple ? 'Add photos' : 'Add photo',
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
