import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/app_preferences.dart';
import '../../models/models.dart';

String _currencyForCountry(String country) {
  final c = country.toLowerCase();
  if (c.contains('uganda')) return 'UGX';
  if (c.contains('kenya')) return 'KES';
  if (c.contains('tanzania')) return 'TZS';
  if (c.contains('rwanda')) return 'RWF';
  if (c.contains('united arab emirates') || c.contains('uae')) return 'AED';
  if (c.contains('united kingdom')) return 'GBP';
  if (c.contains('europe')) return 'EUR';
  return 'USD';
}

final _walletProvider = FutureProvider.autoDispose<WalletModel>((ref) async {
  final currency = _currencyForCountry(ref.watch(userCountryProvider));
  final data = await ref.read(apiServiceProvider).getMyWallet(currency: currency);
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
    // Mobile money fields
    final phoneCtrl = TextEditingController();
    // Card fields
    final cardNumberCtrl = TextEditingController();
    final cardHolderCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final cvvCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isMtn = selectedMethod == 'mtn';
          final isAirtel = selectedMethod == 'airtel';
          final isCard = selectedMethod == 'card';
          final isMobile = isMtn || isAirtel;

          final Color methodColor = isMtn
              ? const Color(0xFFFFC200)
              : isAirtel
                  ? const Color(0xFFE02020)
                  : Theme.of(ctx).colorScheme.primary;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Top Up Wallet'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Conversion rate banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14,
                            color:
                                Theme.of(ctx).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '1 point = 1,000 UGX',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount field
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      hintText: 'e.g. 50',
                      prefixIcon: const Icon(
                          Icons.account_balance_wallet_outlined),
                      suffixText: 'pts',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment method selector
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      prefixIcon: Icon(Icons.payment_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'mtn',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFC200),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('MTN Mobile Money'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'airtel',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE02020),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Airtel Money'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'card',
                        child: Row(
                          children: [
                            const Icon(Icons.credit_card, size: 16),
                            const SizedBox(width: 8),
                            const Text('Credit / Debit Card'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedMethod = v),
                  ),

                  // ── Method-specific fields ──────────────────────────
                  if (isMobile) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: methodColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: methodColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.phone_android,
                                  size: 16, color: methodColor),
                              const SizedBox(width: 6),
                              Text(
                                isMtn
                                    ? 'MTN Mobile Money'
                                    : 'Airtel Money',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: methodColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Mobile Money Number',
                              hintText:
                                  isMtn ? '077XXXXXXX' : '075XXXXXXX',
                              prefixText: '+256 ',
                              prefixIcon: const Icon(Icons.call_outlined),
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isMtn
                                ? 'You will receive an MTN USSD prompt to authorise the payment.'
                                : 'You will receive an Airtel USSD prompt to authorise the payment.',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (isCard) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Theme.of(ctx)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.credit_card,
                                  size: 16,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .primary),
                              const SizedBox(width: 6),
                              Text(
                                'Card Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .primary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: cardNumberCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 16,
                            decoration: const InputDecoration(
                              labelText: 'Card Number',
                              hintText: '16-digit card number',
                              prefixIcon: Icon(Icons.credit_card_outlined),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: cardHolderCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Cardholder Name',
                              hintText: 'As printed on card',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: expiryCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 5,
                                  decoration: const InputDecoration(
                                    labelText: 'Expiry',
                                    hintText: 'MM/YY',
                                    prefixIcon:
                                        Icon(Icons.calendar_today_outlined),
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    counterText: '',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: cvvCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'CVV',
                                    hintText: '3–4 digits',
                                    prefixIcon: Icon(Icons.lock_outline),
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    counterText: '',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.lock,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Your card details are encrypted and secure.',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: Icon(
                  isCard
                      ? Icons.lock_outline
                      : isMobile
                          ? Icons.phone_android
                          : Icons.add,
                  size: 16,
                ),
                label: const Text('Top Up'),
                style: selectedMethod != null
                    ? FilledButton.styleFrom(
                        backgroundColor: methodColor,
                        foregroundColor: isMtn ? Colors.black87 : Colors.white,
                      )
                    : null,
                onPressed: selectedMethod == null
                    ? null
                    : () async {
                        final amt =
                            int.tryParse(amountCtrl.text.trim()) ?? 0;
                        if (amt <= 0) return;
                        // Build a reference from the method-specific fields
                        String? reference;
                        if (isMobile && phoneCtrl.text.trim().isNotEmpty) {
                          reference = phoneCtrl.text.trim();
                        } else if (isCard &&
                            cardNumberCtrl.text.trim().isNotEmpty) {
                          // Store only last 4 digits for reference
                          final digits =
                              cardNumberCtrl.text.replaceAll(' ', '');
                          reference = digits.length >= 4
                              ? digits.substring(digits.length - 4)
                              : digits;
                        }
                        Navigator.pop(ctx);
                         await _doTopup(
                           amount: amt,
                           method: selectedMethod!,
                           currency:
                               _currencyForCountry(ref.read(userCountryProvider)),
                           reference: reference,
                         );
                      },
              ),
            ],
          );
        },
      ),
    );

    amountCtrl.dispose();
    phoneCtrl.dispose();
    cardNumberCtrl.dispose();
    cardHolderCtrl.dispose();
    expiryCtrl.dispose();
    cvvCtrl.dispose();
  }

  Future<void> _doTopup({
    required int amount,
    required String method,
    required String currency,
    String? reference,
  }) async {
    setState(() => _topping = true);
    try {
      await ref.read(apiServiceProvider).topupWallet(
            amount: amount,
            paymentMethod: method,
            currency: currency,
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
                          '${w.points} pts · ${w.displayCurrency} ${w.displayAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
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
                      walletAsync.when(
                        data: (w) => Text(
                          '1 point = 1,000 UGX (rate ${w.exchangeRate.toStringAsFixed(4)} ${w.displayCurrency}/UGX)',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
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
