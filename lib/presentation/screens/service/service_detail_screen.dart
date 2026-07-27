// lib/presentation/screens/service/service_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../widgets/common.dart';
import '../cart/cart_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final int serviceId;

  /// Optional list-view copy so the screen can paint instantly while the
  /// full record loads.
  final Service? preview;

  const ServiceDetailScreen({super.key, required this.serviceId, this.preview});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final _repo = CatalogRepository.instance;

  Service? _service;
  ServiceOption? _option;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.preview;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await _repo.service(widget.serviceId);
      if (!mounted) return;
      setState(() {
        _service = s;
        _option = s.options.isNotEmpty ? s.options.first : null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  double get _price {
    final s = _service;
    if (s == null) return 0;
    return s.basePrice + (_option?.extraPrice ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = _service;

    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _loading
            ? const _DetailSkeleton()
            : ErrorState(message: _error ?? 'Not found', onRetry: _load),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: s.imageUrl != null ? 220 : 0,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: s.imageUrl == null
                ? null
                : FlexibleSpaceBar(
                    background: AppImage(
                      url: s.imageUrl,
                      width: double.infinity,
                      height: 220,
                      radius: 0,
                    ),
                  ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.categoryName != null)
                    Text(
                      s.categoryName!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppTheme.muted,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(s.name, style: Theme.of(context).textTheme.headlineMedium),

                  if (s.shortDesc != null && s.shortDesc!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      s.shortDesc!,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AppTheme.muted,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (s.ratingCount > 0)
                        Pill(
                          icon: Icons.star_rounded,
                          label:
                              '${s.ratingAvg.toStringAsFixed(1)} · ${s.ratingCount} reviews',
                          color: AppTheme.warn,
                        ),
                      if (s.durationMinutes > 0)
                        Pill(
                          icon: Icons.schedule_rounded,
                          label: Fmt.duration(s.durationMinutes),
                        ),
                      if (s.warrantyDays > 0)
                        Pill(
                          icon: Icons.verified_user_rounded,
                          label: '${s.warrantyDays}-day warranty',
                          color: AppTheme.ok,
                        ),
                    ],
                  ),

                  if (s.isInspection) ...[
                    const SizedBox(height: 16),
                    _inspectionNote(s),
                  ],

                  if (s.options.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text('Choose your unit',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _options(s),
                  ],

                  if (s.includes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text("What's included",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ...s.includes.map((e) => _bullet(e, true)),
                  ],

                  if (s.excludes.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('Not included',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ...s.excludes.map((e) => _bullet(e, false)),
                  ],

                  if (s.description != null && s.description!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('About this service',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      s.description!,
                      style: const TextStyle(fontSize: 14.5, height: 1.55),
                    ),
                  ],

                  if (s.warrantyText != null && s.warrantyText!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.ok.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user_rounded,
                              size: 19, color: AppTheme.ok),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.warrantyText!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: AppTheme.ok,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (s.faqs.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Common questions',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    ...s.faqs.map(_faq),
                  ],

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(s),
    );
  }

  /* ---------------------------------------------------------------- parts */
  Widget _inspectionNote(Service s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, size: 19, color: AppTheme.info),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Priced after inspection',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.info,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s.visitCharge > 0
                      ? 'You pay ${Fmt.money(s.visitCharge)} for the visit. The technician '
                          'quotes the repair on site and you approve it in the app before '
                          'any work starts.'
                      : 'The technician quotes the repair on site and you approve it in '
                          'the app before any work starts.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.info,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _options(Service s) {
    return Column(
      children: s.options.map((o) {
        final selected = _option?.id == o.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => setState(() => _option = o),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                    : Colors.white,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : AppTheme.line,
                  width: selected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : AppTheme.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      o.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    o.extraPrice > 0
                        ? '+${Fmt.money(o.extraPrice)}'
                        : Fmt.money(s.basePrice),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _bullet(String text, bool positive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            positive ? Icons.check_rounded : Icons.close_rounded,
            size: 17,
            color: positive ? AppTheme.ok : AppTheme.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: positive ? AppTheme.ink : AppTheme.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faq(Map<String, dynamic> f) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          f['question']?.toString() ?? '',
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        children: [
          Text(
            f['answer']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------------------------------------------------------- bar */
  Widget _bottomBar(Service s) {
    final cart = context.watch<CartProvider>();
    final inCart = cart.contains(s.id, optionId: _option?.id);

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
              Text(
                s.isInspection ? 'Visit charge' : 'Total',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
              ),
              const SizedBox(height: 1),
              Text(
                s.isInspection
                    ? (s.visitCharge > 0 ? Fmt.money(s.visitCharge) : 'On inspection')
                    : Fmt.money(_price),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (inCart) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                  return;
                }
                context.read<CartProvider>().add(s, option: _option);
                showSnack(context, 'Added to cart');
              },
              child: Text(inCart ? 'Go to cart' : 'Add to cart'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shim(height: 200, radius: 14),
          SizedBox(height: 20),
          Shim(width: 220, height: 26),
          SizedBox(height: 12),
          Shim(height: 16),
          SizedBox(height: 8),
          Shim(width: 260, height: 16),
          SizedBox(height: 26),
          Shim(height: 56, radius: 12),
          SizedBox(height: 10),
          Shim(height: 56, radius: 12),
        ],
      ),
    );
  }
}
