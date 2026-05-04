import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';

/// A button that appears next to a description [TextEditingController] field.
/// When tapped it calls the ORT AI backend to auto-generate a listing
/// description and inserts the result into the controller.
///
/// Usage:
/// ```dart
/// AiDescriptionButton(
///   controller: _descriptionController,
///   listingType: 'property',
///   getTitle: () => _titleController.text,
///   getCategory: () => _selectedCategory,
///   getLocation: () => _locationController.text,
/// )
/// ```
class AiDescriptionButton extends ConsumerStatefulWidget {
  const AiDescriptionButton({
    super.key,
    required this.controller,
    required this.listingType,
    required this.getTitle,
    this.getCategory,
    this.getLocation,
    this.getExtraContext,
  });

  final TextEditingController controller;

  /// One of: property, agriculture, manufacturing_product, manufacturing_service
  final String listingType;

  final String Function() getTitle;
  final String? Function()? getCategory;
  final String? Function()? getLocation;
  final String? Function()? getExtraContext;

  @override
  ConsumerState<AiDescriptionButton> createState() => _AiDescriptionButtonState();
}

class _AiDescriptionButtonState extends ConsumerState<AiDescriptionButton> {
  bool _busy = false;

  Future<void> _generate() async {
    final title = widget.getTitle().trim();
    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a title before generating a description.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final description = await ref.read(apiServiceProvider).generateAiDescription(
            listingType: widget.listingType,
            title: title,
            category: widget.getCategory?.call(),
            location: widget.getLocation?.call(),
            extraContext: widget.getExtraContext?.call(),
          );
      if (mounted) {
        widget.controller.text = description;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: description.length),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI description failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Auto-fill with AI',
      child: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.auto_awesome_rounded),
              color: Theme.of(context).colorScheme.primary,
              onPressed: _generate,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
    );
  }
}
