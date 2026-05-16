import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';

final _ordersListProvider =
    FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final auth = ref.read(authProvider);
  final userId = auth.userId;
  if (userId == null) return const <OrderModel>[];

  final role = auth.role ?? 'user';
  final api = ref.read(apiServiceProvider);

  List<dynamic> data;
  if (role == 'user') {
    data = await api.getOrders(buyerUserId: userId, limit: 50);
  } else {
    final tenant = await api.getTenantByOwner(userId);
    final tenantId = tenant?['id'] as int?;
    if (tenantId == null) return const <OrderModel>[];
    data = await api.getOrders(sellerTenantId: tenantId, limit: 50);
  }

  return data
      .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_ordersListProvider);
    final role = ref.watch(authProvider).role ?? 'user';
    final isBusinessRole =
        role == 'agent' || role == 'company' || role == 'organization';

    return Scaffold(
      appBar: AppBar(
        title: Text(isBusinessRole ? 'Business Orders' : 'My Orders'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                isBusinessRole
                    ? 'No business orders yet.'
                    : 'No orders yet.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_ordersListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final o = items[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _statusColor(o.status).withValues(alpha: 0.1),
                      child:
                          Icon(Icons.shopping_bag, color: _statusColor(o.status)),
                    ),
                    title: Text(o.orderNumber,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${o.items.length} item(s) • ${o.currency} ${o.totalAmount?.toStringAsFixed(2) ?? '-'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(o.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                o.status.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              o.paymentStatus.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Track order',
                          icon: const Icon(Icons.local_shipping_outlined),
                          onPressed: () => ctx.go('/tracking/${o.id}'),
                        ),
                      ],
                    ),
                    onTap: () => ctx.go('/orders/${o.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'delivered':
        return Colors.green;
      case 'processing':
      case 'shipped':
        return Colors.blue;
      case 'cancelled':
      case 'disputed':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
