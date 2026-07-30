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
      'https://web-production-61eb1b.up.railway.app/api';

  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 60);

  // ---------------------------------------------------------------- app
  static const String appName = 'Mistrio';
  static const String platform = 'user';

  // ---------------------------------------------------------------- auth
  /// Sends the OTP from our own backend instead of Firebase Phone Auth.
  ///
  /// Firebase requires a billing account for phone sign-in in most regions.
  /// While that is not set up, this routes login through
  /// `/auth/user/send-otp` and `/auth/user/verify-otp`, which the backend
  /// already supports. It is the same login flow, the same user record and
  /// the same token — only the delivery of the code differs.
  ///
  /// Requires `OTP_MASTER_CODE` to be set in the Railway variables.
  ///
  /// Set this to false once Firebase billing is enabled.
  static const bool useBackendOtp = false;

  /// Shown on the login screen while [useBackendOtp] is on, so a test build
  /// cannot be mistaken for a real one.
  static const bool showTestModeBanner = useBackendOtp;

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
