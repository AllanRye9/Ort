import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_preferences.dart';

/// A compact bar shown below the search bar on listing screens.
///
/// • In **Local** mode it shows a small "📍 Local – <country>" badge.
/// • In **International** mode it shows an "🌍 International" badge plus a
///   scrollable row of country filter chips (matching the home screen).
///
/// When the user picks a country chip, [intlCountryFilterProvider] is updated
/// which causes the listing screens (which watch the provider) to reload
/// automatically.
class ModeFilterBar extends ConsumerWidget {
  const ModeFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(marketplaceModeProvider);
    final userCountry = ref.watch(userCountryProvider);
    final intlFilter = ref.watch(intlCountryFilterProvider);
    final notifier = ref.read(intlCountryFilterProvider.notifier);
    final isLocal = mode == MarketplaceMode.local;

    if (isLocal) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 13, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              'Local · $userCountry',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // International mode – show badge + country chips.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_outlined, size: 13, color: Colors.blue),
              const SizedBox(width: 4),
              const Text(
                'International',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (intlFilter.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  '· $intlFilter',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: intlFilter.isEmpty,
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 11),
                    padding: EdgeInsets.zero,
                    onSelected: (_) => notifier.clear(),
                  ),
                ),
                ...kInternationalCountries.map((country) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(country),
                        selected: intlFilter == country,
                        visualDensity: VisualDensity.compact,
                        labelStyle: const TextStyle(fontSize: 11),
                        padding: EdgeInsets.zero,
                        onSelected: (_) => intlFilter == country
                            ? notifier.clear()
                            : notifier.setFilter(country),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
