// lib/data/providers/config_provider.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Holds everything the server decides: colours, support numbers, tax,
/// payment methods, force-update and maintenance state.
///
/// Nothing user-facing should be hardcoded in a screen. If a screen needs a
/// value, it comes from here.
class ConfigProvider extends ChangeNotifier {
  final _api = ApiClient.instance;

  Map<String, dynamic> _config = Map.from(AppConstants.fallbackConfig);
  List<Map<String, dynamic>> _cities = const [];

  bool _loading = true;
  bool _loadedFromServer = false;
  String? _error;

  bool _updateRequired = false;
  bool _forceUpdate = false;
  String _updateMessage = '';
  bool _maintenance = false;
  String _maintenanceMessage = '';

  String? _pincode;
  String? _city;

  // ---------------------------------------------------------------- getters
  bool get loading => _loading;
  bool get loadedFromServer => _loadedFromServer;
  String? get error => _error;

  bool get updateRequired => _updateRequired;
  bool get forceUpdate => _forceUpdate;
  String get updateMessage => _updateMessage;
  bool get maintenance => _maintenance;
  String get maintenanceMessage => _maintenanceMessage;

  List<Map<String, dynamic>> get cities => _cities;
  String? get pincode => _pincode;
  String? get city => _city;
  bool get hasLocation => _pincode != null && _pincode!.isNotEmpty;

  // ---------------------------------------------------------------- values
  T value<T>(String key, T fallback) {
    final v = _config[key];
    if (v == null) return fallback;
    if (T == double) return (v is num ? v.toDouble() : fallback) as T;
    if (T == int) return (v is num ? v.toInt() : fallback) as T;
    if (T == bool) return (v is bool ? v : fallback) as T;
    if (T == String) return v.toString() as T;
    return v as T;
  }

  String get brandName => value<String>('brand_name', 'Mistrio');
  String get tagline => value<String>('brand_tagline', '');
  Color get primaryColor =>
      AppTheme.fromHex(value<String>('primary_color', ''), AppTheme.indigo);
  Color get accentColor =>
      AppTheme.fromHex(value<String>('accent_color', ''), AppTheme.amber);

  String get supportPhone => value<String>('support_phone', '');
  String get supportWhatsapp => value<String>('support_whatsapp', '');
  String get supportEmail => value<String>('support_email', '');

  String get termsUrl => value<String>('terms_url', '');
  String get privacyUrl => value<String>('privacy_url', '');
  String get refundUrl => value<String>('refund_policy_url', '');

  double get gstPercent => value<double>('gst_percent', 0);
  int get maxAdvanceDays => value<int>('max_advance_days', 30);

  bool get onlineEnabled => value<bool>('enable_online_payment', true);
  bool get codEnabled => value<bool>('enable_cod', true);
  bool get walletEnabled => value<bool>('enable_wallet', true);
  bool get partsShopEnabled => value<bool>('enable_parts_shop', true);

  double get referralRewardFriend => value<double>('referral_reward_friend', 0);
  double get referralRewardUser => value<double>('referral_reward_user', 0);

  int get cancelFreeWindowMin => value<int>('cancel_free_window_min', 60);
  double get cancelPenalty => value<double>('cancel_penalty_amount', 0);

  double get minWalletTopup => value<double>('min_wallet_topup', 100);
  double get maxWalletTopup => value<double>('max_wallet_topup', 50000);

  ThemeData get theme =>
      AppTheme.build(primary: primaryColor, accent: accentColor);

  // ---------------------------------------------------------------- load
  Future<void> load({String? appVersion, bool force = false}) async {
    if (!force) await _loadCache();

    try {
      final data = await _api.get('/app-config', query: {
        'platform': AppConstants.platform,
        if (appVersion != null) 'app_version': appVersion,
      });

      _config = Map<String, dynamic>.from(data['config'] as Map);
      _cities = ((data['cities'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final update = (data['update'] as Map?) ?? const {};
      _updateRequired = update['update_required'] == true;
      _forceUpdate = update['force_update'] == true;
      _updateMessage = update['message']?.toString() ?? '';

      final maint = (data['maintenance'] as Map?) ?? const {};
      _maintenance = maint['enabled'] == true;
      _maintenanceMessage = maint['message']?.toString() ?? '';

      _loadedFromServer = true;
      _error = null;
      await _saveCache();
    } on ApiException catch (e) {
      // A cached config is better than a dead app.
      _error = _loadedFromServer ? null : e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- location
  Future<void> restoreLocation() async {
    final prefs = await SharedPreferences.getInstance();
    _pincode = prefs.getString(AppConstants.kPincode);
    _city = prefs.getString(AppConstants.kCity);
    notifyListeners();
  }

  Future<bool> checkServiceable(String pincode) async {
    try {
      final data = await _api.get('/service-areas/check', query: {'pincode': pincode});
      final ok = data['serviceable'] == true;
      if (ok) await setLocation(pincode, data['city']?.toString());
      return ok;
    } on ApiException {
      return false;
    }
  }

  Future<void> setLocation(String pincode, String? city) async {
    _pincode = pincode;
    _city = city;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.kPincode, pincode);
    if (city != null) await prefs.setString(AppConstants.kCity, city);
    notifyListeners();
  }

  Future<void> clearLocation() async {
    _pincode = null;
    _city = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.kPincode);
    await prefs.remove(AppConstants.kCity);
    notifyListeners();
  }

  // ---------------------------------------------------------------- cache
  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.kConfig);
      if (raw == null) return;
      _config = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      notifyListeners();
    } catch (_) {
      // A corrupt cache is not worth crashing over.
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.kConfig, jsonEncode(_config));
      await prefs.setInt(
        AppConstants.kConfigAt,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }
}
