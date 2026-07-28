// lib/data/repositories/booking_repository.dart

import '../../core/api/api_client.dart';
import '../models/models.dart';

/// What the server returns after a booking is created.
class BookingResult {
  final int bookingId;
  final String bookingCode;
  final bool needsPayment;
  final double payableNow;
  final double walletUsed;

  const BookingResult({
    required this.bookingId,
    required this.bookingCode,
    this.needsPayment = false,
    this.payableNow = 0,
    this.walletUsed = 0,
  });

  factory BookingResult.fromJson(Map<String, dynamic> j) {
    final booking = (j['booking'] as Map?) ?? const {};
    return BookingResult(
      bookingId: (booking['id'] as num?)?.toInt() ?? 0,
      bookingCode: j['booking_code']?.toString() ?? '',
      needsPayment: j['needs_payment'] == true,
      payableNow: (j['payable_now'] as num?)?.toDouble() ?? 0,
      walletUsed: (j['wallet_used'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A Razorpay order, created server-side so the amount can never be edited
/// by the app.
class PaymentOrder {
  final String orderId;
  final String keyId;
  final double amount;
  final int amountPaise;
  final String name;
  final String description;
  final Map<String, dynamic> prefill;

  const PaymentOrder({
    required this.orderId,
    required this.keyId,
    required this.amount,
    required this.amountPaise,
    required this.name,
    required this.description,
    this.prefill = const {},
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> j) => PaymentOrder(
        orderId: j['order_id']?.toString() ?? '',
        keyId: j['key_id']?.toString() ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        amountPaise: (j['amount_paise'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? 'Mistrio',
        description: j['description']?.toString() ?? '',
        prefill: Map<String, dynamic>.from((j['prefill'] as Map?) ?? const {}),
      );
}

class BookingRepository {
  BookingRepository._();
  static final BookingRepository instance = BookingRepository._();

  final _api = ApiClient.instance;

  /* ---------------------------------------------------------------- address */
  Future<List<Address>> addresses() async {
    final data = await _api.get('/addresses');
    return (data as List)
        .map((e) => Address.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Address> createAddress({
    required String label,
    required String pincode,
    String? house,
    String? area,
    String? landmark,
    String? city,
    String? state,
    double? lat,
    double? lng,
    bool isDefault = false,
  }) async {
    final data = await _api.post('/addresses', body: {
      'label': label,
      'pincode': pincode,
      'house': house,
      'area': area,
      'landmark': landmark,
      'city': city,
      'state': state,
      'lat': lat,
      'lng': lng,
      'is_default': isDefault,
    });
    return Address.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Address> updateAddress(int id, Map<String, dynamic> body) async {
    final data = await _api.put('/addresses/$id', body: body);
    return Address.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteAddress(int id) => _api.delete('/addresses/$id');

  /* ---------------------------------------------------------------- booking */
  Future<BookingResult> createBooking({
    required List<Map<String, dynamic>> items,
    required int addressId,
    required DateTime scheduledDate,
    required int slotId,
    required String paymentMode,
    String? couponCode,
    bool useWallet = false,
    String? notes,
  }) async {
    final iso = '${scheduledDate.year.toString().padLeft(4, '0')}-'
        '${scheduledDate.month.toString().padLeft(2, '0')}-'
        '${scheduledDate.day.toString().padLeft(2, '0')}';

    final data = await _api.post('/bookings', body: {
      'items': items,
      'address_id': addressId,
      'scheduled_date': iso,
      'slot_id': slotId,
      'payment_mode': paymentMode,
      if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
      'use_wallet': useWallet,
      if (notes != null && notes.isNotEmpty) 'user_notes': notes,
    });

    return BookingResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Map<String, dynamic>> bookingDetail(int id) async {
    final data = await _api.get('/bookings/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> myBookings({
    String tab = 'all',
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get('/bookings', query: {
      'tab': tab,
      'page': page,
      'limit': limit,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> cancelBooking(int id, {String? reason}) =>
      _api.post('/bookings/$id/cancel', body: {'reason': reason});

  Future<void> rescheduleBooking(
    int id, {
    required DateTime date,
    required int slotId,
  }) {
    final iso = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return _api.post('/bookings/$id/reschedule',
        body: {'scheduled_date': iso, 'slot_id': slotId});
  }

  Future<void> respondToExtraCharge(int bookingId, int chargeId, bool approve) =>
      _api.post('/bookings/$bookingId/extra-charges/$chargeId/respond',
          body: {'approve': approve});

  Future<void> review(
    int bookingId, {
    required int rating,
    String? comment,
  }) =>
      _api.post('/bookings/$bookingId/review',
          body: {'rating': rating, 'comment': comment});

  /* ---------------------------------------------------------------- payment */
  Future<PaymentOrder> createPaymentOrder({int? bookingId, double? walletTopup}) async {
    final data = await _api.post('/payments/order', body: {
      if (bookingId != null) 'booking_id': bookingId,
      if (walletTopup != null) 'wallet_topup': walletTopup,
    });
    return PaymentOrder.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final data = await _api.post('/payments/verify', body: {
      'razorpay_order_id': orderId,
      'razorpay_payment_id': paymentId,
      'razorpay_signature': signature,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> wallet() async {
    final data = await _api.get('/wallet');
    return Map<String, dynamic>.from(data as Map);
  }
}
