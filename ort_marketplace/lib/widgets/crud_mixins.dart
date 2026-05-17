import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';
import '../core/auth_provider.dart';
import '../core/listing_providers.dart';
import '../core/location_service.dart';

/// Mixin for managing form state across create/edit listing screens.
/// Provides standard form controllers, validation helpers, and submission logic.
mixin FormStateMixin {
  final formKey = GlobalKey<FormState>();
  bool isSubmitting = false;

  /// Validate form and return success/failure.
  bool validateForm() => formKey.currentState?.validate() ?? false;

  /// Show snackbar message to user.
  void showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show error snackbar.
  void showErrorSnackBar(BuildContext context, String message) =>
      showSnackBar(context, message, isError: true);
}

/// Mixin for managing location capture (GPS + geocoding).
mixin LocationCaptureMixin {
  double? geocodedLat;
  double? geocodedLon;
  String? geocodedDisplayName;
  String? geocodedCountry;
  bool isGeocoding = false;
  bool isGpsCapturing = false;
  String? locationError;

  /// Capture GPS location from device.
  Future<bool> captureGpsLocation(WidgetRef ref, VoidCallback updateState) async {
    updateState();
    try {
      final pos = await LocationService.instance.requestAndGetPosition();
      if (pos == null) {
        locationError = 'Could not get GPS location. Check permissions.';
        updateState();
        return false;
      }
      geocodedLat = pos.latitude;
      geocodedLon = pos.longitude;
      geocodedDisplayName =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      locationError = null;
      updateState();
      return true;
    } catch (_) {
      locationError = 'GPS capture failed. Please try again.';
      updateState();
      return false;
    }
  }

  /// Geocode place name to coordinates.
  Future<bool> geocodePlaceName(
    String query,
    WidgetRef ref,
    VoidCallback updateState,
  ) async {
    if (query.trim().isEmpty) return false;

    isGeocoding = true;
    locationError = null;
    geocodedLat = null;
    geocodedLon = null;
    geocodedDisplayName = null;
    updateState();

    try {
      final result =
          await LocationService.instance.geocodeAddressDetailed(query);
      if (result == null) {
        locationError =
            "Place doesn't exist on Map. Please correct the spelling or use a more recognised landmark.";
        isGeocoding = false;
        updateState();
        return false;
      }
      geocodedLat = result.latitude;
      geocodedLon = result.longitude;
      geocodedDisplayName = result.displayName;
      geocodedCountry = result.country;
      locationError = null;
      isGeocoding = false;
      updateState();
      return true;
    } catch (_) {
      locationError =
          'Map service is unreachable. Please check your connection.';
      isGeocoding = false;
      updateState();
      return false;
    }
  }

  /// Check if location is valid (lat/lon set).
  bool hasValidLocation() => geocodedLat != null && geocodedLon != null;

  /// Get location requirement error message if location missing.
  String? getLocationErrorMessage() {
    if (!hasValidLocation()) {
      return 'Location is required. Use GPS (Option A) or enter a place name (Option B).';
    }
    return null;
  }
}

/// Mixin for managing detail screen state (loading, saving, contact).
mixin DetailScreenMixin {
  bool isSaved = false;
  bool isSaveBusy = false;

  /// Load saved state from API.
  Future<void> loadSavedState(
    WidgetRef ref,
    String itemType,
    int itemId,
    VoidCallback updateState,
  ) async {
    try {
      final api = ref.read(apiServiceProvider);
      final userId = ref.read(authProvider).userId;
      if (userId == null) return;
      final saved =
          await api.checkSaved(userId: userId, itemType: itemType, itemId: itemId);
      isSaved = saved;
      updateState();
    } catch (_) {
      // Silent fail on load
    }
  }

  /// Toggle save state for item.
  Future<bool> toggleSave(
    WidgetRef ref,
    BuildContext context,
    String itemType,
    int itemId,
    VoidCallback updateState,
  ) async {
    if (isSaveBusy) return false;
    isSaveBusy = true;
    updateState();

    try {
      final api = ref.read(apiServiceProvider);
      final userId = ref.read(authProvider).userId;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to save items.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        isSaveBusy = false;
        updateState();
        return false;
      }

      if (isSaved) {
        await api.unsaveItem(
          userId: userId,
          itemType: itemType,
          itemId: itemId,
        );
      } else {
        await api.saveItem(
          userId: userId,
          itemType: itemType,
          itemId: itemId,
        );
      }
      isSaved = !isSaved;
      isSaveBusy = false;
      updateState();
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      isSaveBusy = false;
      updateState();
      return false;
    }
  }
}

/// Mixin for managing image uploads/selection in listings.
mixin ImageHandlingMixin {
  List<String> imageUrls = [];

  /// Update image URLs from picker.
  void onImagesChanged(List<String> urls) {
    imageUrls = urls;
  }

  /// Get images for API payload (empty list omitted).
  Map<String, dynamic> getImagePayload() {
    if (imageUrls.isEmpty) return {};
    return {'images': imageUrls};
  }
}

/// Mixin for common dialog/feedback UI patterns.
mixin UIHelpersMixin {
  /// Show loading dialog.
  void showLoadingDialog(BuildContext context, {String message = 'Loading...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Close loading dialog.
  void closeDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Show confirmation dialog.
  Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.pop(_, true),
              child: Text(confirmText),
            ),
          ],
        ),
      );
}

/// Helper for building section headers in forms.
class FormSectionHeader extends StatelessWidget {
  const FormSectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
  }
}

/// Helper for building location capture section.
class LocationCaptureSection extends StatelessWidget {
  const LocationCaptureSection({
    super.key,
    required this.onCaptureGps,
    required this.onGeocodePlace,
    required this.geocodedDisplayName,
    required this.isGeocoding,
    required this.isGpsCapturing,
    required this.locationError,
    required this.placeNameController,
  });

  final VoidCallback onCaptureGps;
  final Future<void> Function(String) onGeocodePlace;
  final String? geocodedDisplayName;
  final bool isGeocoding;
  final bool isGpsCapturing;
  final String? locationError;
  final TextEditingController placeNameController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormSectionHeader('LOCATION *'),
        if (geocodedDisplayName == null)
          Text(
            'At least one location option is required.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        if (locationError != null) ...[
          const SizedBox(height: 8),
          Text(
            locationError!,
            style: TextStyle(fontSize: 11, color: Colors.red),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Option A – Use my current GPS location',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: isGpsCapturing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location, size: 18),
          label: Text(
            isGpsCapturing ? 'Getting location…' : 'Capture GPS Location',
          ),
          onPressed: (isGpsCapturing || isGeocoding) ? null : onCaptureGps,
        ),
        const SizedBox(height: 12),
        Text(
          'Option B – Enter place name',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: placeNameController,
          decoration: InputDecoration(
            labelText: 'Place Name',
            hintText: 'e.g. Kampala, Nakasero',
            suffixIcon: isGeocoding
                ? const SizedBox(
                    width: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: (value) {
            // Debounce would be good here
          },
          onFieldSubmitted: onGeocodePlace,
        ),
        if (geocodedDisplayName != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    geocodedDisplayName!,
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
