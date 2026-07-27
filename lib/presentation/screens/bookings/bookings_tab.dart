// lib/presentation/screens/bookings/bookings_tab.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../widgets/common.dart';
import 'booking_detail_screen.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My bookings'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _BookingList(tab: 'upcoming'),
          _BookingList(tab: 'completed'),
          _BookingList(tab: 'cancelled'),
        ],
      ),
    );
  }
}

class _BookingList extends StatefulWidget {
  final String tab;

  const _BookingList({required this.tab});

  @override
  State<_BookingList> createState() => _BookingListState();
}

class _BookingListState extends State<_BookingList>
    with AutomaticKeepAliveClientMixin {
  final _repo = BookingRepository.instance;

  List<BookingSummary> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _poll;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();

    // Active jobs move without the customer doing anything, so keep this
    // tab honest. The other tabs are static and are not polled.
    if (widget.tab == 'upcoming') {
      _poll = Timer.periodic(const Duration(seconds: 45), (_) => _load(silent: true));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = _items.isEmpty);
    try {
      final data = await _repo.myBookings(tab: widget.tab, limit: 30);
      if (!mounted) return;
      setState(() {
        _items = ((data['items'] as List?) ?? [])
            .map((e) => BookingSummary.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const Shim(height: 132, radius: 14),
      );
    }

    if (_error != null && _items.isEmpty) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    if (_items.isEmpty) {
      return EmptyState(
        icon: widget.tab == 'upcoming'
            ? Icons.event_available_rounded
            : Icons.receipt_long_rounded,
        title: switch (widget.tab) {
          'upcoming' => 'No active bookings',
          'completed' => 'Nothing completed yet',
          _ => 'Nothing cancelled',
        },
        message: widget.tab == 'upcoming'
            ? 'When you book a service it will appear here so you can track it.'
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _BookingCard(
          booking: _items[i],
          onChanged: _load,
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingSummary booking;
  final VoidCallback onChanged;

  const _BookingCard({required this.booking, required this.onChanged});

  Color get _statusColour {
    if (StatusText.isDead(booking.status)) return AppTheme.danger;
    if (StatusText.isDone(booking.status)) return AppTheme.ok;
    if (booking.status == 'in_progress') return AppTheme.warn;
    if (booking.status == 'partner_on_the_way' || booking.status == 'arrived') {
      return AppTheme.info;
    }
    return AppTheme.muted;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailScreen(bookingId: booking.id),
          ),
        );
        onChanged();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            // Status strip — readable before any text is parsed.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColour.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _statusColour,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    StatusText.of(booking.status),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _statusColour,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    booking.code,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.services ?? 'Service',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 14, color: AppTheme.muted),
                      const SizedBox(width: 6),
                      Text(
                        '${Fmt.dayName(booking.scheduledDate)}'
                        '${booking.slotLabel != null ? ' · ${booking.slotLabel}' : ''}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.muted),
                      ),
                    ],
                  ),

                  if (booking.technicianName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.engineering_rounded,
                            size: 14, color: AppTheme.muted),
                        const SizedBox(width: 6),
                        Text(
                          booking.technicianName!,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        Fmt.money(booking.total),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      if (booking.paymentStatus == 'paid')
                        const Pill(label: 'Paid', color: AppTheme.ok)
                      else if (booking.paymentMode == 'cod')
                        const Pill(label: 'Pay after work'),
                      const Spacer(),
                      if (StatusText.isDone(booking.status) && !booking.hasReview)
                        const Pill(
                            label: 'Rate this visit', color: AppTheme.warn)
                      else
                        const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.muted),
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
}
