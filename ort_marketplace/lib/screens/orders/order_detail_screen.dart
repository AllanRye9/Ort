import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';

final _orderDetailProvider =
    FutureProvider.autoDispose.family<OrderModel, int>((ref, id) async {
  final data = await ref.read(apiServiceProvider).getOrder(id);
  return OrderModel.fromJson(data);
});

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_orderDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Order Detail')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (o) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            o.orderNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          _StatusBadge(status: o.status),
                        ],
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                          label: 'Payment',
                          value: o.paymentStatus.toUpperCase()),
                      if (o.paymentMethod != null)
                        _InfoRow(label: 'Method', value: o.paymentMethod!),
                      _InfoRow(
                          label: 'Total',
                          value:
                              '${o.currency} ${o.totalAmount?.toStringAsFixed(2) ?? '-'}'),
                      if (o.deliveryAddress != null)
                        _InfoRow(
                            label: 'Delivery', value: o.deliveryAddress!),
                      _InfoRow(
                          label: 'Placed',
                          value:
                              '${o.createdAt.day}/${o.createdAt.month}/${o.createdAt.year}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Items',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...o.items.map(
                (item) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: Text(_itemTitle(item)),
                    subtitle: Text(
                        'Qty: ${item.quantity}  ×  ${o.currency} ${item.unitPrice.toStringAsFixed(2)}'),
                    trailing: Text(
                      '${o.currency} ${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              if (o.notes != null) ...[
                const SizedBox(height: 16),
                const Text('Notes',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(o.notes!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _itemTitle(OrderItemModel item) {
    if (item.propertyId != null) return 'Property #${item.propertyId}';
    if (item.agricultureListingId != null)
      return 'Agriculture #${item.agricultureListingId}';
    if (item.manufacturingProductId != null)
      return 'Product #${item.manufacturingProductId}';
    return 'Item';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color get _color {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'disputed':
        return Colors.red;
      case 'shipped':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration:
            BoxDecoration(color: _color, borderRadius: BorderRadius.circular(20)),
        child: Text(status.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}
