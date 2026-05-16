import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';

final _myRfqsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.read(authProvider);
  if (auth.userId == null) return const [];
  if (auth.role != 'user') return const [];
  final data = await ref.read(apiServiceProvider).getRFQs(buyerId: auth.userId);
  return data.cast<Map<String, dynamic>>();
});

class MyRfqsScreen extends ConsumerWidget {
  const MyRfqsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).role ?? 'user';
    if (role != 'user') {
      return const Scaffold(
        body: Center(child: Text('My RFQs is available for standard users only.')),
      );
    }

    final async = ref.watch(_myRfqsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My RFQs')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rfqs) {
          if (rfqs.isEmpty) {
            return const Center(
              child: Text('No RFQ records yet. QR-based claims will appear here.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rfqs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final rfq = rfqs[i];
              final id = rfq['id'];
              final title = rfq['title']?.toString() ?? 'RFQ #$id';
              final status = rfq['status']?.toString() ?? 'open';
              final category = rfq['category']?.toString() ?? 'general';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('QR reference: RFQ-$id'),
                      Text('Category: $category'),
                      Text('Claim status: ${status.toUpperCase()}'),
                      const SizedBox(height: 10),
                      Text(
                        'Use RFQ-$id for QR verification when managing purchase claims.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
