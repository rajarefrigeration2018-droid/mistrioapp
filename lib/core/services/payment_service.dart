// lib/core/services/payment_service.dart

import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../data/repositories/booking_repository.dart';
import '../api/api_client.dart';

enum PaymentOutcome { success, failed, cancelled }

class PaymentResult {
  final PaymentOutcome outcome;
  final String? message;
  final String? paymentId;

  const PaymentResult(this.outcome, {this.message, this.paymentId});

  bool get ok => outcome == PaymentOutcome.success;
}

/// Wraps Razorpay's callback API in a Future so checkout can simply await it.
///
/// The whole flow is server-anchored: the order is created server-side with an
/// amount read from the database, and the result is verified server-side with
/// an HMAC signature check. The app only opens the sheet.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  final _repo = BookingRepository.instance;
  Razorpay? _razorpay;
  Completer<PaymentResult>? _completer;

  /// Opens the Razorpay sheet for a booking and resolves when it closes.
  Future<PaymentResult> payForBooking({
    required int bookingId,
    String? contact,
    String? email,
  }) async {
    PaymentOrder order;
    try {
      order = await _repo.createPaymentOrder(bookingId: bookingId);
    } on ApiException catch (e) {
      return PaymentResult(PaymentOutcome.failed, message: e.message);
    }
    return _open(order, contact: contact, email: email);
  }

  Future<PaymentResult> topUpWallet({
    required double amount,
    String? contact,
    String? email,
  }) async {
    PaymentOrder order;
    try {
      order = await _repo.createPaymentOrder(walletTopup: amount);
    } on ApiException catch (e) {
      return PaymentResult(PaymentOutcome.failed, message: e.message);
    }
    return _open(order, contact: contact, email: email);
  }

  Future<PaymentResult> _open(
    PaymentOrder order, {
    String? contact,
    String? email,
  }) {
    _dispose();

    _completer = Completer<PaymentResult>();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    try {
      _razorpay!.open({
        'key': order.keyId,
        'order_id': order.orderId,
        'amount': order.amountPaise,
        'currency': 'INR',
        'name': order.name,
        'description': order.description,
        'timeout': 300,
        'prefill': {
          'contact': contact ?? order.prefill['contact'] ?? '',
          'email': email ?? order.prefill['email'] ?? '',
          'name': order.prefill['name'] ?? '',
        },
        'theme': {'color': '#1B2A5B'},
        'retry': {'enabled': true, 'max_count': 3},
      });
    } catch (e) {
      _finish(const PaymentResult(
        PaymentOutcome.failed,
        message: 'Could not open the payment screen. Please try again.',
      ));
    }

    return _completer!.future;
  }

  Future<void> _onSuccess(PaymentSuccessResponse response) async {
    // Razorpay says paid; only the server's signature check makes it true.
    try {
      await _repo.verifyPayment(
        orderId: response.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );
      _finish(PaymentResult(
        PaymentOutcome.success,
        paymentId: response.paymentId,
      ));
    } on ApiException catch (e) {
      // Money may have left the customer's account. The webhook will
      // reconcile it, so say so rather than implying it failed outright.
      _finish(PaymentResult(
        PaymentOutcome.failed,
        message: '${e.message} If the amount was debited it will be '
            'confirmed automatically within a few minutes.',
        paymentId: response.paymentId,
      ));
    }
  }

  void _onError(PaymentFailureResponse response) {
    final cancelled = response.code == Razorpay.PAYMENT_CANCELLED;
    _finish(PaymentResult(
      cancelled ? PaymentOutcome.cancelled : PaymentOutcome.failed,
      message: cancelled
          ? 'Payment cancelled.'
          : (response.message ?? 'Payment failed. Please try another method.'),
    ));
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    // The sheet hands off to a wallet app; the webhook settles the booking.
    _finish(const PaymentResult(
      PaymentOutcome.failed,
      message: 'Payment is being processed. We will confirm shortly.',
    ));
  }

  void _finish(PaymentResult result) {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(result);
    }
    _dispose();
  }

  void _dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
