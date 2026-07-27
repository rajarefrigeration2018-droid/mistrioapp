// lib/presentation/screens/checkout/booking_placed_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/config_provider.dart';
import '../home/home_shell.dart';

/// Shown immediately after a booking is created. Deliberately says what
/// happens next rather than just "success" — the moment right after paying is
/// when people most want to know they have not been left in the dark.
class BookingPlacedScreen extends StatelessWidget {
  final int bookingId;
  final String bookingCode;
  final bool paid;

  const BookingPlacedScreen({
    super.key,
    required this.bookingId,
    required this.bookingCode,
    this.paid = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppTheme.ok.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 40, color: AppTheme.ok),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Booking confirmed',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        paid
                            ? 'Payment received. We are finding a technician for you now.'
                            : 'We are finding a technician for you now.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: AppTheme.muted,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 22),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.paper,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'BOOKING ID',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              bookingCode,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppTheme.line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'What happens next',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            _step(
                              1,
                              'We assign a technician',
                              'Usually within a few minutes. You will get their '
                                  'name, photo and phone number.',
                            ),
                            _step(
                              2,
                              'They arrive in your slot',
                              'You can watch them come to you on the map.',
                            ),
                            _step(
                              3,
                              'Share your start code',
                              'Work only begins once you give the technician the '
                                  '4-digit code shown in your booking.',
                              last: true,
                            ),
                          ],
                        ),
                      ),

                      if (config.supportPhone.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Need to change something? Call ${config.supportPhone}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => _goToBookings(context),
                      child: const Text('Track my booking'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _goHome(context),
                      child: const Text('Back to home'),
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

  Widget _step(int n, String title, String body, {bool last = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppTheme.paper,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$n',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                ),
              ),
            ),
            if (!last)
              Container(
                width: 1,
                height: 42,
                color: AppTheme.line,
                margin: const EdgeInsets.symmetric(vertical: 4),
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
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppTheme.muted, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  void _goToBookings(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell(initialTab: 1)),
      (route) => false,
    );
  }
}
