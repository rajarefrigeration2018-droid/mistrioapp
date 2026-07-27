// lib/presentation/screens/bookings/booking_detail_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/config_provider.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../widgets/common.dart';

class BookingDetailScreen extends StatefulWidget {
  final int bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final _repo = BookingRepository.instance;

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = _data == null);
    try {
      final data = await _repo.bookingDetail(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
      _managePolling();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Only poll while something can actually change. A finished job polling
  /// every 20 seconds is a battery leak for no benefit.
  void _managePolling() {
    final status = _booking?['status']?.toString();
    final live = StatusText.isLive(status);

    if (live && _poll == null) {
      _poll = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _load(silent: true),
      );
    } else if (!live) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Map<String, dynamic>? get _booking =>
      _data == null ? null : Map<String, dynamic>.from(_data!['booking'] as Map);

  /* ---------------------------------------------------------------- actions */
  Future<void> _approveCharge(int chargeId, bool approve) async {
    setState(() => _busy = true);
    try {
      await _repo.respondToExtraCharge(widget.bookingId, chargeId, approve);
      await _load(silent: true);
      if (mounted) {
        showSnack(context, approve ? 'Charge approved' : 'Charge declined');
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final fee = (_data!['cancellation_fee'] as num?)?.toDouble() ?? 0;
    final note = _data!['cancellation_note']?.toString();

    final reason = await _askReason(fee, note);
    if (reason == null) return;

    setState(() => _busy = true);
    try {
      await _repo.cancelBooking(widget.bookingId, reason: reason);
      if (!mounted) return;
      context.read<AuthProvider>().refreshUser();
      await _load(silent: true);
      if (mounted) showSnack(context, 'Booking cancelled');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason(double fee, String? note) {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cancel this booking?',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (fee > 0)
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.warn.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      note ??
                          'A cancellation fee of ${Fmt.money(fee)} applies because a '
                              'technician has already been assigned.',
                      style: const TextStyle(
                          fontSize: 13.5, color: AppTheme.warn, height: 1.45),
                    ),
                  )
                else
                  const Text(
                    'No cancellation fee applies. Anything you have paid goes '
                    'back to your wallet.',
                    style: TextStyle(
                        fontSize: 13.5, color: AppTheme.muted, height: 1.45),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Why are you cancelling? (optional)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Keep it'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger),
                        onPressed: () =>
                            Navigator.pop(ctx, controller.text.trim().isEmpty
                                ? 'Cancelled by customer'
                                : controller.text.trim()),
                        child: const Text('Cancel booking'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reschedule() async {
    final catalog = CatalogRepository.instance;
    final config = context.read<ConfigProvider>();

    DateTime picked = DateTime.now();
    List<TimeSlot> slots = [];
    TimeSlot? slot;
    bool loading = true;

    Future<void> loadSlots(StateSetter refresh) async {
      refresh(() => loading = true);
      try {
        slots = await catalog.slots(picked);
        slot = slots.where((s) => s.available).firstOrNull;
      } catch (_) {
        slots = [];
      }
      refresh(() => loading = false);
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) {
          if (loading && slots.isEmpty) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => loadSlots(refresh));
          }

          final days = List.generate(
            config.maxAdvanceDays.clamp(1, 14),
            (i) => DateTime(
                DateTime.now().year, DateTime.now().month, DateTime.now().day + i),
          );

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pick a new time',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text(
                    'Your current technician will be released and we will '
                    'assign someone for the new slot.',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.muted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: days.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final d = days[i];
                        final on = d.day == picked.day && d.month == picked.month;
                        return InkWell(
                          onTap: () {
                            picked = d;
                            loadSlots(refresh);
                          },
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            width: 62,
                            decoration: BoxDecoration(
                              color: on
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Colors.white,
                              border: Border.all(
                                  color: on
                                      ? Theme.of(ctx).colorScheme.primary
                                      : AppTheme.line),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${d.day}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: on ? Colors.white : AppTheme.ink,
                                    )),
                                Text(
                                  const [
                                    'Jan','Feb','Mar','Apr','May','Jun',
                                    'Jul','Aug','Sep','Oct','Nov','Dec'
                                  ][d.month - 1],
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
                  const SizedBox(height: 16),
                  if (loading)
                    const Shim(height: 44, radius: 11)
                  else if (slots.where((s) => s.available).isEmpty)
                    const Text('No slots free on this day.',
                        style: TextStyle(fontSize: 13.5, color: AppTheme.warn))
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView(
                        shrinkWrap: true,
                        children: slots.map((s) {
                          final on = slot?.id == s.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: s.available
                                  ? () => refresh(() => slot = s)
                                  : null,
                              borderRadius: BorderRadius.circular(11),
                              child: Opacity(
                                opacity: s.available ? 1 : 0.45,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: on
                                            ? Theme.of(ctx).colorScheme.primary
                                            : AppTheme.line,
                                        width: on ? 1.5 : 1),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        on
                                            ? Icons.radio_button_checked_rounded
                                            : Icons
                                                .radio_button_unchecked_rounded,
                                        size: 19,
                                        color: on
                                            ? Theme.of(ctx).colorScheme.primary
                                            : AppTheme.muted,
                                      ),
                                      const SizedBox(width: 11),
                                      Text(s.label,
                                          style: const TextStyle(fontSize: 14.5)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: slot == null
                        ? null
                        : () => Navigator.pop(ctx, true),
                    child: const Text('Confirm new time'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirmed != true || slot == null) return;

    setState(() => _busy = true);
    try {
      await _repo.rescheduleBooking(widget.bookingId,
          date: picked, slotId: slot!.id);
      await _load(silent: true);
      if (mounted) showSnack(context, 'Booking rescheduled');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();

    final result = await PaymentService.instance.payForBooking(
      bookingId: widget.bookingId,
      contact: auth.user?.phone,
      email: auth.user?.email,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.ok) {
      await _load(silent: true);
      if (mounted) showSnack(context, 'Payment received');
      auth.refreshUser();
    } else {
      showSnack(context, result.message ?? 'Payment failed', danger: true);
    }
  }

  Future<void> _rate() async {
    int rating = 5;
    final comment = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How did it go?',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    _booking?['partner_name'] != null
                        ? 'Your feedback helps ${_booking!['partner_name']} and other customers.'
                        : 'Your feedback helps other customers.',
                    style: const TextStyle(fontSize: 13.5, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final filled = i < rating;
                        return IconButton(
                          onPressed: () => refresh(() => rating = i + 1),
                          icon: Icon(
                            filled ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 38,
                            color: filled ? AppTheme.warn : AppTheme.line,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comment,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      hintText: 'Anything you want to add? (optional)',
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Submit rating'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (submitted != true) return;

    setState(() => _busy = true);
    try {
      await _repo.review(widget.bookingId,
          rating: rating, comment: comment.text.trim());
      await _load(silent: true);
      if (mounted) showSnack(context, 'Thanks for your feedback');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openInvoice() async {
    final url = _booking?['invoice_url']?.toString();
    if (url == null || url.isEmpty) {
      showSnack(context, 'Invoice is not ready yet', danger: true);
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /* ---------------------------------------------------------------- build */
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Shim(height: 90, radius: 14),
              SizedBox(height: 12),
              Shim(height: 130, radius: 14),
              SizedBox(height: 12),
              Shim(height: 180, radius: 14),
            ],
          ),
        ),
      );
    }

    if (_error != null && _data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking')),
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }

    final b = _booking!;
    final status = b['status']?.toString() ?? '';
    final pending = (_data!['pending_approval'] as List?) ?? [];
    final otp = _data!['start_otp']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(b['booking_code']?.toString() ?? 'Booking'),
        actions: [
          if (StatusText.isDone(status))
            IconButton(
              onPressed: _openInvoice,
              icon: const Icon(Icons.receipt_long_rounded),
              tooltip: 'Invoice',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _statusBanner(status),

            // Approval prompt sits above everything — it is the one thing
            // that blocks the technician from finishing.
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...pending.map((c) =>
                  _approvalCard(Map<String, dynamic>.from(c as Map))),
            ],

            if (otp != null && otp.isNotEmpty) ...[
              const SizedBox(height: 12),
              _otpCard(otp),
            ],

            if (b['partner_name'] != null) ...[
              const SizedBox(height: 12),
              _technicianCard(b),
            ],

            if (_shouldShowMap(status, b)) ...[
              const SizedBox(height: 12),
              _map(b),
            ],

            const SizedBox(height: 12),
            _scheduleCard(b),

            const SizedBox(height: 12),
            _billCard(),

            const SizedBox(height: 12),
            _timelineCard(),

            const SizedBox(height: 16),
            ..._actions(status, b),
          ],
        ),
      ),
    );
  }

  /* ---------------------------------------------------------------- pieces */
  Widget _statusBanner(String status) {
    final done = StatusText.isDone(status);
    final dead = StatusText.isDead(status);
    final colour = dead
        ? AppTheme.danger
        : done
            ? AppTheme.ok
            : status == 'in_progress'
                ? AppTheme.warn
                : AppTheme.info;

    final message = switch (status) {
      'pending' => 'Complete the payment to confirm this booking.',
      'confirmed' => 'We are finding a technician for you.',
      'assigned' => 'A technician has been assigned and will arrive in your slot.',
      'partner_on_the_way' => 'Your technician is on the way.',
      'arrived' => 'Your technician has arrived. Share your start code.',
      'in_progress' => 'Work is in progress.',
      'completed' || 'paid' => 'This job is complete.',
      'cancelled' || 'rejected' => 'This booking was cancelled.',
      _ => '',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            child: Icon(
              dead
                  ? Icons.close_rounded
                  : done
                      ? Icons.check_rounded
                      : Icons.schedule_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  StatusText.of(status),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colour),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                        fontSize: 13,
                        color: colour.withValues(alpha: 0.85),
                        height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalCard(Map<String, dynamic> charge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warn.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.warn.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded,
                  size: 20, color: AppTheme.warn),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Approval needed',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warn),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    charge['label']?.toString() ?? 'Extra work',
                    style: const TextStyle(fontSize: 14.5),
                  ),
                ),
                Text(
                  Fmt.money((charge['amount'] as num?)?.toDouble() ?? 0),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your technician found something extra. Nothing is billed until '
            'you approve it.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.warn, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _approveCharge(
                          (charge['id'] as num).toInt(), false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () =>
                          _approveCharge((charge['id'] as num).toInt(), true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _otpCard(String otp) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            'YOUR START CODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            otp.split('').join('  '),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Give this to your technician only after they arrive. Work cannot '
            'start without it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _technicianCard(Map<String, dynamic> b) {
    final rating = (b['partner_rating'] as num?)?.toDouble() ?? 0;
    final jobs = (b['partner_jobs'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AppImage(
            url: b['partner_photo']?.toString(),
            width: 52,
            height: 52,
            radius: 26,
            fallbackIcon: Icons.engineering_rounded,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR TECHNICIAN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: AppTheme.muted,
                    )),
                const SizedBox(height: 3),
                Text(
                  b['partner_name']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (rating > 0) ...[
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppTheme.warn),
                      const SizedBox(width: 3),
                      Text(rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 12.5, color: AppTheme.muted)),
                      const SizedBox(width: 8),
                    ],
                    if (jobs > 0)
                      Text('$jobs jobs done',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppTheme.muted)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _call(b['partner_phone']?.toString()),
            icon: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.ok.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_rounded, color: AppTheme.ok, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowMap(String status, Map<String, dynamic> b) {
    if (status != 'partner_on_the_way' && status != 'arrived') return false;
    return b['partner_lat'] != null && b['partner_lng'] != null;
  }

  Widget _map(Map<String, dynamic> b) {
    final lat = (b['partner_lat'] as num).toDouble();
    final lng = (b['partner_lng'] as num).toDouble();
    final snap = Map<String, dynamic>.from((b['addr_snapshot'] as Map?) ?? {});
    final homeLat = (snap['lat'] as num?)?.toDouble();
    final homeLng = (snap['lng'] as num?)?.toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 200,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng),
            zoom: 14,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('technician'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                  title: b['partner_name']?.toString() ?? 'Technician'),
            ),
            if (homeLat != null && homeLng != null)
              Marker(
                markerId: const MarkerId('home'),
                position: LatLng(homeLat, homeLng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure),
                infoWindow: const InfoWindow(title: 'Your address'),
              ),
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          liteModeEnabled: true,
        ),
      ),
    );
  }

  Widget _scheduleCard(Map<String, dynamic> b) {
    final snap = Map<String, dynamic>.from((b['addr_snapshot'] as Map?) ?? {});
    final address = [
      snap['house'], snap['area'], snap['landmark'], snap['city'], snap['pincode']
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _row(Icons.calendar_today_rounded, 'When',
              '${Fmt.dayName(b['scheduled_date'])}'
              '${b['slot_label'] != null ? '\n${b['slot_label']}' : ''}'),
          const Divider(height: 20),
          _row(Icons.location_on_rounded, 'Where', address),
          if ((b['user_notes']?.toString() ?? '').isNotEmpty) ...[
            const Divider(height: 20),
            _row(Icons.sticky_note_2_rounded, 'Your note',
                b['user_notes'].toString()),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: AppTheme.muted,
                  )),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(fontSize: 14, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _billCard() {
    final b = _booking!;
    final items = (_data!['items'] as List?) ?? [];
    final extras = (_data!['extra_charges'] as List?) ?? [];

    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BILL',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: AppTheme.muted,
              )),
          const SizedBox(height: 12),

          ...items.map((raw) {
            final i = Map<String, dynamic>.from(raw as Map);
            final qty = (i['qty'] as num?)?.toInt() ?? 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${i['service_name']}'
                      '${i['option_name'] != null ? ' · ${i['option_name']}' : ''}'
                      '${qty > 1 ? ' × $qty' : ''}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(Fmt.money(n(i['line_total'])),
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            );
          }),

          ...extras.map((raw) {
            final e = Map<String, dynamic>.from(raw as Map);
            final rejected = e['rejected'] == true;
            final approved = e['approved_by_user'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e['label']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: rejected ? AppTheme.muted : AppTheme.ink,
                              decoration: rejected
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                        Text(
                          rejected
                              ? 'Declined'
                              : approved
                                  ? 'Approved by you'
                                  : 'Waiting for your approval',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(Fmt.money(n(e['amount'])),
                      style: TextStyle(
                        fontSize: 14,
                        color: rejected ? AppTheme.muted : AppTheme.ink,
                        decoration:
                            rejected ? TextDecoration.lineThrough : null,
                      )),
                ],
              ),
            );
          }),

          const Divider(height: 18),
          _billLine('Item total', n(b['subtotal'])),
          if (n(b['extra_charges_total']) > 0)
            _billLine('Extra charges', n(b['extra_charges_total'])),
          if (n(b['visit_charge']) > 0)
            _billLine('Visit charge', n(b['visit_charge'])),
          if (n(b['discount']) > 0)
            _billLine(
              b['coupon_code'] != null
                  ? 'Discount (${b['coupon_code']})'
                  : 'Discount',
              -n(b['discount']),
              good: true,
            ),
          if (n(b['tax']) > 0) _billLine('GST', n(b['tax'])),
          if (n(b['cancellation_fee']) > 0)
            _billLine('Cancellation fee', n(b['cancellation_fee'])),

          const Divider(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text('Total',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Text(Fmt.money(n(b['total'])),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                b['payment_status'] == 'paid'
                    ? 'Paid'
                    : b['payment_mode'] == 'cod'
                        ? 'Pay the technician after the work'
                        : 'Payment pending',
                style: TextStyle(
                  fontSize: 12.5,
                  color: b['payment_status'] == 'paid'
                      ? AppTheme.ok
                      : AppTheme.muted,
                  fontWeight: b['payment_status'] == 'paid'
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billLine(String label, double value, {bool good = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.muted)),
          ),
          Text(
            Fmt.money(value.abs()).replaceFirst('₹', value < 0 ? '− ₹' : '₹'),
            style: TextStyle(
              fontSize: 13.5,
              color: good ? AppTheme.ok : AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineCard() {
    final timeline = (_data!['timeline'] as List?) ?? [];
    if (timeline.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PROGRESS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: AppTheme.muted,
              )),
          const SizedBox(height: 14),
          ...timeline.asMap().entries.map((entry) {
            final t = Map<String, dynamic>.from(entry.value as Map);
            final last = entry.key == timeline.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!last)
                      Container(
                        width: 1,
                        height: 32,
                        color: AppTheme.line,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: last ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          StatusText.of(t['status']?.toString()),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          Fmt.timeAgo(t['created_at']),
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _actions(String status, Map<String, dynamic> b) {
    final canCancel = _data!['can_cancel'] == true;
    final canReschedule = _data!['can_reschedule'] == true;
    final canReview = _data!['can_review'] == true;
    final needsPayment = b['payment_status'] != 'paid' &&
        b['payment_mode'] == 'online' &&
        !StatusText.isDead(status);

    return [
      if (needsPayment)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ElevatedButton(
            onPressed: _busy ? null : _pay,
            child: Text('Pay ${Fmt.money((b['total'] as num?)?.toDouble() ?? 0)}'),
          ),
        ),

      if (canReview)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _rate,
            icon: const Icon(Icons.star_rounded, size: 20),
            label: const Text('Rate this visit'),
          ),
        ),

      if (canReschedule)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            onPressed: _busy ? null : _reschedule,
            child: const Text('Change date or time'),
          ),
        ),

      if (canCancel)
        OutlinedButton(
          onPressed: _busy ? null : _cancel,
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
          child: const Text('Cancel booking'),
        ),

      const SizedBox(height: 16),
      Center(
        child: TextButton.icon(
          onPressed: () {
            final phone = context.read<ConfigProvider>().supportPhone;
            if (phone.isEmpty) return;
            _call(phone);
          },
          icon: const Icon(Icons.support_agent_rounded, size: 19),
          label: const Text('Need help with this booking?'),
        ),
      ),
    ];
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
