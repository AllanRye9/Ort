import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_service.dart';

Future<void> triggerImageSearch({
  required BuildContext context,
  required WidgetRef ref,
  required ValueChanged<String> onQuery,
}) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery);
  if (picked == null) return;

  final bytes = await picked.readAsBytes();
  if (bytes.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not read selected image.')),
    );
    return;
  }

  final filename = picked.name.isNotEmpty ? picked.name : 'image.jpg';
  await ref.read(apiServiceProvider).uploadImage(
        bytes: bytes,
        filename: filename,
        mimeType: _mimeTypeFromFilename(filename),
      );

  final query = await _confirmQuery(
    context,
    suggested: _queryFromFilename(filename),
  );
  if (query == null || query.trim().isEmpty) return;
  onQuery(query);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Image search started.')),
  );
}

Future<String?> _confirmQuery(
  BuildContext context, {
  required String suggested,
}) async {
  final ctrl = TextEditingController(text: suggested);
  final query = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Image search'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Search keywords',
          hintText: 'Describe what to search',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          child: const Text('Search'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return query;
}

String _queryFromFilename(String filename) {
  final noExt = filename.replaceFirst(RegExp(r'\.[^.]+$'), '');
  final cleaned = noExt.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ').trim();
  return cleaned.isEmpty ? 'listing' : cleaned;
}

String _mimeTypeFromFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
