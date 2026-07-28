// lib/core/utils/formatters.dart

import 'package:intl/intl.dart';

class Fmt {
  Fmt._();

  static final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String money(num? value) => _money.format(value ?? 0);

  static String moneyShort(num? value) {
    final v = (value ?? 0).toDouble();
    if (v.abs() >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v.abs() >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    if (v.abs() >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
    return money(v);
  }

  static String date(dynamic value) {
    final d = _parse(value);
    return d == null ? '—' : DateFormat('d MMM yyyy').format(d);
  }

  static String dateShort(dynamic value) {
    final d = _parse(value);
    return d == null ? '—' : DateFormat('d MMM').format(d);
  }

  /// "Today", "Tomorrow", or "Mon, 4 Aug".
  static String dayName(dynamic value) {
    final d = _parse(value);
    if (d == null) return '—';
    final now = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(d);
  }

  static String timeAgo(dynamic value) {
    final d = _parse(value);
    if (d == null) return '—';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dateShort(d);
  }

  static String phone(String? value) {
    if (value == null || value.isEmpty) return '—';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final last10 =
        digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return last10.length == 10
        ? '${last10.substring(0, 5)} ${last10.substring(5)}'
        : value;
  }

  static String duration(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  static DateTime? _parse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

/// Booking status written the way a customer would understand it.
class StatusText {
  StatusText._();

  static const Map<String, String> _labels = {
    'pending': 'Payment pending',
    'confirmed': 'Confirmed',
    'assigned': 'Technician assigned',
    'partner_on_the_way': 'On the way',
    'arrived': 'Arrived',
    'in_progress': 'Work in progress',
    'completed': 'Completed',
    'paid': 'Completed',
    'cancelled': 'Cancelled',
    'rejected': 'Cancelled',
    'rescheduled': 'Rescheduled',
    'placed': 'Order placed',
    'packed': 'Packed',
    'shipped': 'Shipped',
    'delivered': 'Delivered',
    'returned': 'Returned',
  };

  static String of(String? status) => _labels[status] ?? (status ?? '—');

  static bool isLive(String? status) => const [
        'confirmed',
        'assigned',
        'partner_on_the_way',
        'arrived',
        'in_progress',
      ].contains(status);

  static bool isDone(String? status) => status == 'completed' || status == 'paid';

  static bool isDead(String? status) => status == 'cancelled' || status == 'rejected';
}
