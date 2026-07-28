// lib/data/providers/cart_provider.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import '../repositories/catalog_repository.dart';

/// Holds the cart and the server-calculated totals.
///
/// The app deliberately does not compute any total. Every change fires a
/// `/price-preview` call and the screen renders exactly what comes back. That
/// means a tampered build cannot change what a customer pays.
class CartProvider extends ChangeNotifier {
  final _repo = CatalogRepository.instance;

  final List<CartItem> _items = [];
  PriceBreakup? _breakup;
  String? _couponCode;
  bool _pricing = false;
  String? _error;
  Timer? _debounce;

  // ---------------------------------------------------------------- getters
  List<CartItem> get items => List.unmodifiable(_items);
  PriceBreakup? get breakup => _breakup;
  String? get couponCode => _couponCode;
  bool get pricing => _pricing;
  String? get error => _error;

  bool get isEmpty => _items.isEmpty;
  int get count => _items.fold(0, (sum, i) => sum + i.qty);
  double get total => _breakup?.total ?? 0;

  bool get hasInspectionItem => _items.any((i) => i.service.isInspection);

  // ---------------------------------------------------------------- restore
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.kCart);
      if (raw == null) return;

      final list = jsonDecode(raw) as List;
      _items
        ..clear()
        ..addAll(list.map(
          (e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)),
        ));

      if (_items.isNotEmpty) {
        notifyListeners();
        unawaited(_reprice());
      }
    } catch (_) {
      // A corrupt cart is not worth a crash — start empty.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_items.isEmpty) {
        await prefs.remove(AppConstants.kCart);
      } else {
        await prefs.setString(
          AppConstants.kCart,
          jsonEncode(_items.map((i) => i.toJson()).toList()),
        );
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------- mutate
  int _indexOf(int serviceId, int? optionId) =>
      _items.indexWhere((i) => i.serviceId == serviceId && i.optionId == optionId);

  bool contains(int serviceId, {int? optionId}) => _indexOf(serviceId, optionId) >= 0;

  int qtyOf(int serviceId, {int? optionId}) {
    final i = _indexOf(serviceId, optionId);
    return i < 0 ? 0 : _items[i].qty;
  }

  void add(Service service, {ServiceOption? option, int qty = 1}) {
    final index = _indexOf(service.id, option?.id);
    if (index >= 0) {
      _items[index].qty += qty;
    } else {
      _items.add(CartItem(service: service, option: option, qty: qty));
    }
    _after();
  }

  void setQty(int serviceId, int? optionId, int qty) {
    final index = _indexOf(serviceId, optionId);
    if (index < 0) return;
    if (qty <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].qty = qty;
    }
    _after();
  }

  void increment(CartItem item) => setQty(item.serviceId, item.optionId, item.qty + 1);
  void decrement(CartItem item) => setQty(item.serviceId, item.optionId, item.qty - 1);

  void remove(CartItem item) => setQty(item.serviceId, item.optionId, 0);

  void clear() {
    _items.clear();
    _breakup = null;
    _couponCode = null;
    _error = null;
    _after(immediate: true);
  }

  void _after({bool immediate = false}) {
    notifyListeners();
    unawaited(_persist());
    if (_items.isEmpty) {
      _breakup = null;
      notifyListeners();
      return;
    }
    if (immediate) {
      unawaited(_reprice());
    } else {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () => _reprice());
    }
  }

  // ---------------------------------------------------------------- coupon
  Future<bool> applyCoupon(String code) async {
    _couponCode = code.trim().toUpperCase();
    await _reprice();
    final applied = _breakup?.couponApplied ?? false;
    if (!applied) _couponCode = null;
    notifyListeners();
    return applied;
  }

  Future<void> removeCoupon() async {
    _couponCode = null;
    await _reprice();
  }

  // ---------------------------------------------------------------- pricing
  Future<void> refresh() => _reprice();

  Future<void> _reprice({bool useWallet = false}) async {
    if (_items.isEmpty) {
      _breakup = null;
      notifyListeners();
      return;
    }

    _pricing = true;
    _error = null;
    notifyListeners();

    try {
      _breakup = await _repo.pricePreview(
        items: _items.map((i) => i.toRequest()).toList(),
        couponCode: _couponCode,
        useWallet: useWallet,
      );
    } on ApiException catch (e) {
      _error = e.message;
      // A service going out of stock or inactive should not strand the cart.
      if (e.code == 'INVALID_CART') _breakup = null;
    } finally {
      _pricing = false;
      notifyListeners();
    }
  }

  /// Called from checkout when the wallet toggle changes.
  Future<void> repriceWithWallet(bool useWallet) => _reprice(useWallet: useWallet);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
