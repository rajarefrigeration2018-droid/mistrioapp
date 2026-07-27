// lib/presentation/widgets/service_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/providers/cart_provider.dart';
import '../screens/service/service_detail_screen.dart';
import 'common.dart';

/// A service in a vertical list. Tapping anywhere opens the detail; the Add
/// button is the shortcut for services with no options to choose.
class ServiceCard extends StatelessWidget {
  final Service service;

  const ServiceCard({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.qtyOf(service.id);
    final hasDiscount = service.strikePrice != null &&
        service.strikePrice! > service.basePrice &&
        !service.isInspection;

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(url: service.imageUrl, width: 76, height: 76, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (service.shortDesc != null && service.shortDesc!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      service.shortDesc!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (service.ratingCount > 0)
                        Pill(
                          icon: Icons.star_rounded,
                          label:
                              '${service.ratingAvg.toStringAsFixed(1)} (${service.ratingCount})',
                          color: AppTheme.warn,
                        ),
                      if (service.durationMinutes > 0)
                        Pill(
                          icon: Icons.schedule_rounded,
                          label: Fmt.duration(service.durationMinutes),
                        ),
                      if (service.warrantyDays > 0)
                        Pill(
                          icon: Icons.verified_user_rounded,
                          label: '${service.warrantyDays}-day warranty',
                          color: AppTheme.ok,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              service.priceLabel(Fmt.money),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 6),
                              Text(
                                Fmt.money(service.strikePrice),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.muted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _AddButton(service: service, qty: qty),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(serviceId: service.id, preview: service),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final Service service;
  final int qty;

  const _AddButton({required this.service, required this.qty});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cart = context.read<CartProvider>();

    if (qty == 0) {
      return SizedBox(
        height: 34,
        child: OutlinedButton(
          onPressed: () {
            // Services with options must be configured on the detail screen.
            if (service.options.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ServiceDetailScreen(serviceId: service.id, preview: service),
                ),
              );
              return;
            }
            cart.add(service);
            showSnack(context, 'Added to cart');
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(74, 34),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            side: BorderSide(color: primary),
            foregroundColor: primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          child: const Text('Add'),
        ),
      );
    }

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _step(Icons.remove_rounded,
              () => cart.setQty(service.id, null, qty - 1)),
          Container(
            constraints: const BoxConstraints(minWidth: 22),
            alignment: Alignment.center,
            child: Text(
              '$qty',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          _step(Icons.add_rounded, () => cart.setQty(service.id, null, qty + 1)),
        ],
      ),
    );
  }

  Widget _step(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
      );
}
