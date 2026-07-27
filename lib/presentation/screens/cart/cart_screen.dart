// lib/presentation/screens/cart/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/cart_provider.dart';
import '../../widgets/common.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _coupon = TextEditingController();
  bool _applying = false;

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _coupon.text.trim();
    if (code.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _applying = true);

    final cart = context.read<CartProvider>();
    final ok = await cart.applyCoupon(code);

    if (!mounted) return;
    setState(() => _applying = false);

    if (ok) {
      _coupon.clear();
      showSnack(context, cart.breakup?.couponMessage ?? 'Coupon applied');
    } else {
      showSnack(
        context,
        cart.breakup?.couponMessage ?? 'That code did not work',
        danger: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () async {
                final yes = await confirmSheet(
                  context,
                  title: 'Empty the cart?',
                  message: 'This removes every service you have added.',
                  confirmLabel: 'Empty cart',
                  danger: true,
                );
                if (yes && context.mounted) {
                  context.read<CartProvider>().clear();
                }
              },
              child: const Text('Clear'),
            ),
        ],
      ),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add a service and it will show up here.',
              actionLabel: 'Browse services',
              onAction: () => Navigator.pop(context),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                ...cart.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CartRow(item: item),
                    )),

                const SizedBox(height: 8),
                _couponBox(cart),

                const SizedBox(height: 16),
                _breakupBox(cart),

                if (cart.hasInspectionItem) ...[
                  const SizedBox(height: 14),
                  _inspectionNote(),
                ],

                if (cart.error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 19, color: AppTheme.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cart.error!,
                            style: const TextStyle(
                                fontSize: 13.5, color: AppTheme.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: cart.isEmpty ? null : _checkoutBar(cart),
    );
  }

  /* ---------------------------------------------------------------- coupon */
  Widget _couponBox(CartProvider cart) {
    final applied = cart.breakup?.couponApplied ?? false;

    if (applied) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.ok.withValues(alpha: 0.07),
          border: Border.all(color: AppTheme.ok.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer_rounded, size: 18, color: AppTheme.ok),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.breakup!.couponCode} applied',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ok,
                    ),
                  ),
                  if (cart.breakup?.couponMessage != null)
                    Text(
                      cart.breakup!.couponMessage!,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.ok),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.read<CartProvider>().removeCoupon(),
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _coupon,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Coupon code',
              prefixIcon: Icon(Icons.local_offer_outlined, size: 19),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            onSubmitted: (_) => _applyCoupon(),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: _applying ? null : _applyCoupon,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(84, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: _applying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Apply'),
          ),
        ),
      ],
    );
  }

  /* ---------------------------------------------------------------- totals */
  Widget _breakupBox(CartProvider cart) {
    final b = cart.breakup;

    if (b == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          children: [
            Shim(height: 14),
            SizedBox(height: 10),
            Shim(height: 14),
            SizedBox(height: 10),
            Shim(height: 18),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Rendered exactly as the server sent it — the app adds nothing.
          ...b.lines.map((line) {
            final bold = line['bold'] == true;
            final good = line['highlight'] == true;
            final value = (line['value'] as num?)?.toDouble() ?? 0;

            return Padding(
              padding: EdgeInsets.only(bottom: bold ? 0 : 9),
              child: Column(
                children: [
                  if (bold) const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          line['label']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: bold ? 16 : 14,
                            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                            color: bold ? AppTheme.ink : AppTheme.muted,
                          ),
                        ),
                      ),
                      Text(
                        Fmt.money(value.abs()).replaceFirst('₹', value < 0 ? '− ₹' : '₹'),
                        style: TextStyle(
                          fontSize: bold ? 17 : 14,
                          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                          color: good ? AppTheme.ok : AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _inspectionNote() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, size: 18, color: AppTheme.info),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'One of your services is priced after inspection. You pay only the '
              'visit charge now — the repair cost is quoted on site and you approve '
              'it in the app.',
              style: TextStyle(fontSize: 13, color: AppTheme.info, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------------------------------------------------------- bar */
  Widget _checkoutBar(CartProvider cart) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.muted)),
              const SizedBox(height: 1),
              cart.pricing
                  ? const Shim(width: 70, height: 22)
                  : Text(
                      Fmt.money(cart.total),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: cart.pricing || cart.breakup == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CheckoutScreen(),
                        ),
                      ),
              child: const Text('Proceed to book'),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------- row */
class _CartRow extends StatelessWidget {
  final CartItem item;

  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final unit = item.service.basePrice + (item.option?.extraPrice ?? 0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(url: item.service.imageUrl, width: 56, height: 56, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.service.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                if (item.option != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.option!.name,
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      item.service.isInspection
                          ? (item.service.visitCharge > 0
                              ? '${Fmt.money(item.service.visitCharge)} visit'
                              : 'On inspection')
                          : Fmt.money(unit),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    _stepper(cart, primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepper(CartProvider cart, Color primary) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: primary),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => cart.decrement(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Icon(
                item.qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                size: 16,
                color: item.qty == 1 ? AppTheme.danger : primary,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            alignment: Alignment.center,
            child: Text(
              '${item.qty}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: primary,
              ),
            ),
          ),
          InkWell(
            onTap: () => cart.increment(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Icon(Icons.add_rounded, size: 16, color: primary),
            ),
          ),
        ],
      ),
    );
  }
}
