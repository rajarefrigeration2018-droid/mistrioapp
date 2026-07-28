// lib/core/constants/app_constants.dart

/// The ONE place the backend URL is written.
///
/// When you buy a domain, change [apiBaseUrl] here and nothing else.
/// No other file in this app may contain a hostname.
class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------- network
  /// Railway URL for now. Swap for `https://api.yourdomain.in/api` at launch.
  static const String apiBaseUrl =
      'https://mistrio-backend-production.up.railway.app/api';

  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 60);

  // ---------------------------------------------------------------- app
  static const String appName = 'Mistrio';
  static const String platform = 'user';

  // ---------------------------------------------------------------- storage
  static const String kToken = 'mistrio_token';
  static const String kUser = 'mistrio_user';
  static const String kConfig = 'mistrio_config';
  static const String kConfigAt = 'mistrio_config_at';
  static const String kPincode = 'mistrio_pincode';
  static const String kCity = 'mistrio_city';
  static const String kOnboarded = 'mistrio_onboarded';
  static const String kCart = 'mistrio_cart';

  /// How long a cached catalogue stays fresh before we refetch.
  static const Duration cacheTtl = Duration(hours: 6);

  // ---------------------------------------------------------------- fallbacks
  // Used only if /app-config cannot be reached on a cold start.
  // The server copy always wins.
  static const Map<String, dynamic> fallbackConfig = {
    'brand_name': 'Mistrio',
    'brand_tagline': 'Trusted repairs, right at home',
    'primary_color': '#1B2A5B',
    'accent_color': '#FFB300',
    'support_phone': '',
    'support_whatsapp': '',
    'support_email': '',
    'gst_percent': 18,
    'enable_online_payment': true,
    'enable_cod': true,
    'enable_wallet': true,
    'enable_parts_shop': true,
    'maintenance_mode': false,
  };

  // ---------------------------------------------------------------- routes
  static const String rSplash = '/';
  static const String rOnboarding = '/onboarding';
  static const String rLogin = '/login';
  static const String rHome = '/home';
  static const String rCategory = '/category';
  static const String rService = '/service';
  static const String rCart = '/cart';
  static const String rCheckout = '/checkout';
  static const String rBookings = '/bookings';
  static const String rBooking = '/booking';
  static const String rAddresses = '/addresses';
  static const String rWallet = '/wallet';
  static const String rParts = '/parts';
  static const String rProfile = '/profile';
}
