// lib/presentation/screens/checkout/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/providers/config_provider.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../widgets/common.dart';
import '../address/address_sheet.dart';
import 'booking_placed_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _bookings = BookingRepository.instance;
  final _catalog = CatalogRepository.instance;
  final _notes = TextEditingController();

  List<Address> _addresses = [];
  Address? _address;

  late DateTime _date;
  List<TimeSlot> _slots = [];
  TimeSlot? _slot;

  String _paymentMode = 'cod';
  bool _useWallet = false;

  bool _loadingAddresses = true;
  bool _loadingSlots = false;
  bool _placing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _loadAddresses();
    _loadSlots();

    // Default to whichever method the admin has enabled.
    final config = context.read<ConfigProvider>();
    if (!config.codEnabled) {
      _paymentMode = config.onlineEnabled ? 'online' : 'wallet';
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /* ---------------------------------------------------------------- load */
  Future<void> _loadAddresses() async {
    setState(() => _loadingAddresses = true);
    try {
      final list = await _bookings.addresses();
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _address = list.where((a) => a.isDefault).firstOrNull ??
            (list.isNotEmpty ? list.first : null);
        _loadingAddresses = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingAddresses = false;
      });
    }
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slot = null;
    });
    try {
      final list = await _catalog.slots(_date);
      if (!mounted) return;
      setState(() {
        _slots = list;
        _slot = list.where((s) => s.available).firstOrNull;
        _loadingSlots = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingSlots = false;
      });
    }
  }

  /* ---------------------------------------------------------------- place */
  Future<void> _place() async {
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();

    if (_address == null) {
      _snack('Choose where the technician should come');
      return;
    }
    if (_slot == null) {
      _snack('Choose a time slot');
      return;
    }

    setState(() {
      _placing = true;
      _error = null;
    });

    try {
      final result = await _bookings.createBooking(
        items: cart.items.map((i) => i.toRequest()).toList(),
        addressId: _address!.id,
        scheduledDate: _date,
        slotId: _slot!.id,
        paymentMode: _paymentMode,
        couponCode: cart.couponCode,
        useWallet: _useWallet,
        notes: _notes.text.trim(),
      );

      // Cash or wallet: the booking is already confirmed server-side.
      if (!result.needsPayment) {
        _finish(result, paid: _paymentMode != 'cod');
        return;
      }

      // Online: open Razorpay. The booking already exists as pending, so a
      // failed payment leaves a recoverable record rather than nothing.
      final payment = await PaymentService.instance.payForBooking(
        bookingId: result.bookingId,
        contact: auth.user?.phone,
        email: auth.user?.email,
      );

      if (!mounted) return;

      if (payment.ok) {
        _finish(result, paid: true);
      } else {
        setState(() => _placing = false);
        _showPaymentFailed(result, payment.message);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _placing = false;
        _error = e.message;
      });
      _snack(e.message, danger: true);
    }
  }

  void _finish(BookingResult result, {required bool paid}) {
    context.read<CartProvider>().clear();
    context.read<AuthProvider>().refreshUser();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => BookingPlacedScreen(
          bookingId: result.bookingId,
          bookingCode: result.bookingCode,
          paid: paid,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  void _showPaymentFailed(BookingResult result, String? message) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 34, color: AppTheme.warn),
              const SizedBox(height: 12),
              Text('Payment not completed',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                '${message ?? 'The payment did not go through.'}\n\n'
                'Your booking ${result.bookingCode} is saved. Pay from '
                'My Bookings whenever you are ready.',
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.muted, height: 1.5),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _finish(result, paid: false);
                },
                child: const Text('View my booking'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _place();
                },
                child: const Text('Try payment again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String message, {bool danger = false}) =>
      showSnack(context, message, danger: danger);

  /* ---------------------------------------------------------------- build */
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final config = context.watch<ConfigProvider>();

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          actionLabel: 'Go back',
          onAction: () => Navigator.pop(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _addressSection(),
          const SizedBox(height: 22),
          _dateSection(config),
          const SizedBox(height: 22),
          _slotSection(),
          const SizedBox(height: 22),
          _notesSection(),
          const SizedBox(height: 22),
          _paymentSection(config, cart),
          const SizedBox(height: 22),
          _summarySection(cart),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.danger),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _bar(cart),
    );
  }

  /* ---------------------------------------------------------------- address */
  Widget _addressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Where should we come?', '1'),
        const SizedBox(height: 10),

        if (_loadingAddresses)
          const Shim(height: 74, radius: 12)
        else if (_addresses.isEmpty)
          _addFirstAddress()
        else ...[
          AddressTile(
            address: _address!,
            selected: true,
            onEdit: () async {
              final updated =
                  await showAddressSheet(context, existing: _address);
              if (updated != null) _loadAddresses();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_addresses.length > 1)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickAddress,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: const Text('Change address'),
                  ),
                ),
              if (_addresses.length > 1) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final created = await showAddressSheet(context);
                    if (created != null) {
                      await _loadAddresses();
                      if (mounted) setState(() => _address = created);
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add new'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _addFirstAddress() {
    return InkWell(
      onTap: () async {
        final created = await showAddressSheet(context);
        if (created != null) {
          await _loadAddresses();
          if (mounted) setState(() => _address = created);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.line, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(Icons.add_location_alt_outlined,
                size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add your address',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('The technician needs to know where to go.',
                      style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAddress() async {
    final chosen = await showModalBottomSheet<Address>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          children: [
            Text('Choose an address',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 14),
            ..._addresses.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AddressTile(
                    address: a,
                    selected: a.id == _address?.id,
                    onTap: () => Navigator.pop(ctx, a),
                  ),
                )),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _address = chosen);
  }

  /* ---------------------------------------------------------------- date */
  Widget _dateSection(ConfigProvider config) {
    final today = DateTime.now();
    final days = List.generate(
      config.maxAdvanceDays.clamp(1, 14),
      (i) => DateTime(today.year, today.month, today.day + i),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('When?', '2'),
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = days[i];
              final on = d.day == _date.day &&
                  d.month == _date.month &&
                  d.year == _date.year;
              final primary = Theme.of(context).colorScheme.primary;

              return InkWell(
                onTap: () {
                  setState(() => _date = d);
                  _loadSlots();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 68,
                  decoration: BoxDecoration(
                    color: on ? primary : Colors.white,
                    border: Border.all(color: on ? primary : AppTheme.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        i == 0
                            ? 'Today'
                            : i == 1
                                ? 'Tmrw'
                                : _weekday(d),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: on ? Colors.white70 : AppTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.white : AppTheme.ink,
                        ),
                      ),
                      Text(
                        _month(d),
                        style: TextStyle(
                          fontSize: 11,
                          color: on ? Colors.white70 : AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _weekday(DateTime d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

  String _month(DateTime d) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][d.month - 1];

  /* ---------------------------------------------------------------- slot */
  Widget _slotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('What time?', '3'),
        const SizedBox(height: 10),
        if (_loadingSlots)
          Column(
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Shim(height: 50, radius: 12),
              ),
            ),
          )
        else if (_slots.isEmpty)
          _note('No slots configured for this date. Try another day.',
              AppTheme.warn)
        else if (_slots.every((s) => !s.available))
          _note(
            'Every slot on ${Fmt.dayName(_date)} is full. Pick another date.',
            AppTheme.warn,
          )
        else
          ..._slots.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _slotTile(s),
              )),
      ],
    );
  }

  Widget _slotTile(TimeSlot s) {
    final on = _slot?.id == s.id;
    final primary = Theme.of(context).colorScheme.primary;
    final disabled = !s.available;

    return InkWell(
      onTap: disabled ? null : () => setState(() => _slot = s),
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: on ? primary.withValues(alpha: 0.05) : Colors.white,
            border: Border.all(
              color: on ? primary : AppTheme.line,
              width: on ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                on
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: on ? primary : AppTheme.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (disabled)
                Text(
                  s.reason ?? 'Unavailable',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                )
              else if (s.remaining <= 3)
                Pill(label: 'Only ${s.remaining} left', color: AppTheme.warn),
            ],
          ),
        ),
      ),
    );
  }

  /* ---------------------------------------------------------------- notes */
  Widget _notesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Anything we should know?', '4'),
        const SizedBox(height: 10),
        TextField(
          controller: _notes,
          maxLines: 2,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'Gate code, which floor, what the problem sounds like…',
            counterText: '',
            isDense: true,
          ),
        ),
      ],
    );
  }

  /* ---------------------------------------------------------------- payment */
  Widget _paymentSection(ConfigProvider config, CartProvider cart) {
    final wallet = context.watch<AuthProvider>().user?.walletBalance ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('How would you like to pay?', '5'),
        const SizedBox(height: 10),

        if (config.codEnabled)
          _payTile(
            'cod',
            'Pay after the work',
            'Cash or UPI to the technician once the job is done.',
            Icons.payments_outlined,
          ),
        if (config.onlineEnabled)
          _payTile(
            'online',
            'Pay now',
            'UPI, card, netbanking or wallet.',
            Icons.account_balance_wallet_outlined,
          ),

        if (config.walletEnabled && wallet > 0) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              setState(() => _useWallet = !_useWallet);
              cart.repriceWithWallet(_useWallet);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _useWallet
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 21,
                    color: _useWallet
                        ? Theme.of(context).colorScheme.primary
                        : AppTheme.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Use wallet balance (${Fmt.money(wallet)})',
                      style: const TextStyle(fontSize: 14.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _payTile(String value, String title, String subtitle, IconData icon) {
    final on = _paymentMode == value;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _paymentMode = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: on ? primary.withValues(alpha: 0.05) : Colors.white,
            border: Border.all(
              color: on ? primary : AppTheme.line,
              width: on ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                on
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: on ? primary : AppTheme.muted,
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 20, color: AppTheme.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ---------------------------------------------------------------- summary */
  Widget _summarySection(CartProvider cart) {
    final b = cart.breakup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Summary', '6'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              ...cart.items.map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            i.qty > 1 ? '${i.title} × ${i.qty}' : i.title,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 14),
              if (b == null)
                const Shim(height: 18)
              else
                ...b.lines.map((line) {
                  final bold = line['bold'] == true;
                  final good = line['highlight'] == true;
                  final value = (line['value'] as num?)?.toDouble() ?? 0;

                  return Padding(
                    padding: EdgeInsets.only(bottom: bold ? 0 : 8),
                    child: Column(
                      children: [
                        if (bold) const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                line['label']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: bold ? 15.5 : 13.5,
                                  fontWeight:
                                      bold ? FontWeight.w700 : FontWeight.w400,
                                  color: bold ? AppTheme.ink : AppTheme.muted,
                                ),
                              ),
                            ),
                            Text(
                              Fmt.money(value.abs())
                                  .replaceFirst('₹', value < 0 ? '− ₹' : '₹'),
                              style: TextStyle(
                                fontSize: bold ? 16.5 : 13.5,
                                fontWeight:
                                    bold ? FontWeight.w700 : FontWeight.w500,
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
        ),

        if (cart.hasInspectionItem) ...[
          const SizedBox(height: 10),
          _note(
            'One service is priced after inspection. You pay the visit charge '
            'now — the repair amount is quoted on site and you approve it in '
            'the app before any work begins.',
            AppTheme.info,
          ),
        ],
      ],
    );
  }

  /* ---------------------------------------------------------------- bits */
  Widget _heading(String text, String step) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _note(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(CartProvider cart) {
    final ready = _address != null && _slot != null && !cart.pricing;

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
                _paymentMode == 'cod' ? 'Pay later' : 'Pay now',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
              ),
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
              onPressed: ready && !_placing ? _place : null,
              child: _placing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(_paymentMode == 'cod' ? 'Confirm booking' : 'Pay and book'),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
