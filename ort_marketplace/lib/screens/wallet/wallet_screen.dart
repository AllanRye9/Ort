import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../models/models.dart';

final _walletProvider = FutureProvider.autoDispose<WalletModel>((ref) async {
  final data = await ref.read(apiServiceProvider).getMyWallet();
  return WalletModel.fromJson(data);
});

final _txProvider =
    FutureProvider.autoDispose<List<WalletTransactionModel>>((ref) async {
  final list = await ref.read(apiServiceProvider).getWalletTransactions();
  return list
      .map((e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _topping = false;

  Future<void> _showTopupDialog() async {
    String? selectedMethod;
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Top Up Wallet'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Conversion rate: 1 cash unit = 1 point',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (points)',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    prefixIcon: Icon(Icons.payment_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'mtn',
                      child: Text('MTN Mobile Money'),
                    ),
                    DropdownMenuItem(
                      value: 'airtel',
                      child: Text('Airtel Money'),
                    ),
                    DropdownMenuItem(
                      value: 'card',
                      child: Text('Credit / Debit Card'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedMethod = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: refCtrl,
                  decoration: InputDecoration(
                    labelText: selectedMethod == 'card'
                        ? 'Card last 4 digits (optional)'
                        : 'Phone number (optional)',
                    prefixIcon: const Icon(Icons.tag_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedMethod == null
                  ? null
                  : () async {
                      final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amt <= 0) return;
                      Navigator.pop(ctx);
                      await _doTopup(
                        amount: amt,
                        method: selectedMethod!,
                        reference:
                            refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                      );
                    },
              child: const Text('Top Up'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doTopup({
    required int amount,
    required String method,
    String? reference,
  }) async {
    setState(() => _topping = true);
    try {
      await ref.read(apiServiceProvider).topupWallet(
            amount: amount,
            paymentMethod: method,
            reference: reference,
          );
      ref.invalidate(_walletProvider);
      ref.invalidate(_txProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$amount points added to your wallet!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Top-up failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _topping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(_walletProvider);
    final txAsync = ref.watch(_txProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_walletProvider);
              ref.invalidate(_txProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Balance card ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    size: 40, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wallet Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      walletAsync.when(
                        data: (w) => Text(
                          '${w.points} pts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        loading: () => const Text(
                          '…',
                          style: TextStyle(color: Colors.white, fontSize: 32),
                        ),
                        error: (_, __) => const Text(
                          '—',
                          style: TextStyle(color: Colors.white, fontSize: 32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '1 point = 1 cash unit',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Promotion pricing info ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ad Promotion Plans',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _planRow(context, '7 days', '10 points'),
                    _planRow(context, '30 days', '26 points'),
                    _planRow(context, '1 year (365 days)', '300 points'),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Transactions ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Transaction History',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
          Expanded(
            child: txAsync.when(
              data: (txList) => txList.isEmpty
                  ? const Center(child: Text('No transactions yet.'))
                  : ListView.builder(
                      itemCount: txList.length,
                      itemBuilder: (_, i) {
                        final tx = txList[i];
                        final isTopup = tx.transactionType == 'topup';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isTopup
                                ? Colors.green.withValues(alpha: 0.15)
                                : cs.errorContainer,
                            child: Icon(
                              isTopup
                                  ? Icons.add_circle_outline
                                  : Icons.remove_circle_outline,
                              color: isTopup ? Colors.green : cs.error,
                            ),
                          ),
                          title: Text(
                            tx.description ?? tx.transactionType.toUpperCase(),
                          ),
                          subtitle: Text(
                            _formatDate(tx.createdAt),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            '${isTopup ? '+' : '-'}${tx.amount} pts',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isTopup ? Colors.green : cs.error,
                            ),
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _topping ? null : _showTopupDialog,
        icon: _topping
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Top Up'),
      ),
    );
  }

  Widget _planRow(BuildContext context, String label, String cost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(cost,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
