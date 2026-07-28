// lib/data/models/models.dart
//
// Plain data classes. Every fromJson is defensive: the API may add fields,
// and a missing one must never crash the app.

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
int _i(dynamic v) => v == null ? 0 : (v as num).toInt();
String? _s(dynamic v) => v?.toString();
List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

/* ============================================================ USER */
class AppUser {
  final int id;
  final String phone;
  final String? name;
  final String? email;
  final String? profileImage;
  final String? referralCode;
  final double walletBalance;
  final bool profileComplete;

  const AppUser({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.profileImage,
    this.referralCode,
    this.walletBalance = 0,
    this.profileComplete = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _i(j['id']),
        phone: j['phone']?.toString() ?? '',
        name: _s(j['name']),
        email: _s(j['email']),
        profileImage: _s(j['profile_image']),
        referralCode: _s(j['referral_code']),
        walletBalance: _d(j['wallet_balance']),
        profileComplete: j['profile_complete'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'email': email,
        'profile_image': profileImage,
        'referral_code': referralCode,
        'wallet_balance': walletBalance,
        'profile_complete': profileComplete,
      };

  String get displayName => (name?.trim().isNotEmpty ?? false) ? name! : 'there';
  String get initial =>
      (name?.trim().isNotEmpty ?? false) ? name!.trim()[0].toUpperCase() : 'U';
}

/* ============================================================ CATALOGUE */
class Category {
  final int id;
  final String name;
  final String? iconUrl;
  final String? bannerUrl;
  final String? description;
  final int serviceCount;

  const Category({
    required this.id,
    required this.name,
    this.iconUrl,
    this.bannerUrl,
    this.description,
    this.serviceCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: _i(j['id']),
        name: j['name']?.toString() ?? '',
        iconUrl: _s(j['icon_url']),
        bannerUrl: _s(j['banner_url']),
        description: _s(j['description']),
        serviceCount: _i(j['service_count']),
      );
}

class ServiceOption {
  final int id;
  final String name;
  final double extraPrice;

  const ServiceOption({
    required this.id,
    required this.name,
    this.extraPrice = 0,
  });

  factory ServiceOption.fromJson(Map<String, dynamic> j) => ServiceOption(
        id: _i(j['id']),
        name: j['name']?.toString() ?? '',
        extraPrice: _d(j['extra_price']),
      );
}

class Service {
  final int id;
  final int categoryId;
  final String name;
  final String? categoryName;
  final String? shortDesc;
  final String? description;
  final String? imageUrl;
  final double basePrice;
  final double? strikePrice;
  final String priceType; // fixed | starting_from | inspection_based
  final int durationMinutes;
  final double visitCharge;
  final int warrantyDays;
  final String? warrantyText;
  final List<String> includes;
  final List<String> excludes;
  final double ratingAvg;
  final int ratingCount;
  final List<ServiceOption> options;
  final List<Map<String, dynamic>> faqs;

  const Service({
    required this.id,
    required this.categoryId,
    required this.name,
    this.categoryName,
    this.shortDesc,
    this.description,
    this.imageUrl,
    this.basePrice = 0,
    this.strikePrice,
    this.priceType = 'fixed',
    this.durationMinutes = 60,
    this.visitCharge = 0,
    this.warrantyDays = 0,
    this.warrantyText,
    this.includes = const [],
    this.excludes = const [],
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.options = const [],
    this.faqs = const [],
  });

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id: _i(j['id']),
        categoryId: _i(j['category_id']),
        name: j['name']?.toString() ?? '',
        categoryName: _s(j['category_name']),
        shortDesc: _s(j['short_desc']),
        description: _s(j['description']),
        imageUrl: _s(j['image_url']),
        basePrice: _d(j['base_price']),
        strikePrice: j['strike_price'] == null ? null : _d(j['strike_price']),
        priceType: j['price_type']?.toString() ?? 'fixed',
        durationMinutes: j['duration_minutes'] == null ? 60 : _i(j['duration_minutes']),
        visitCharge: _d(j['visit_charge']),
        warrantyDays: _i(j['warranty_days']),
        warrantyText: _s(j['warranty_text']),
        includes: _strList(j['includes']),
        excludes: _strList(j['excludes']),
        ratingAvg: _d(j['rating_avg'] ?? j['rating']),
        ratingCount: _i(j['rating_count']),
        options: (j['options'] as List?)
                ?.map((e) => ServiceOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        faqs: (j['faqs'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [],
      );

  bool get isInspection => priceType == 'inspection_based';
  bool get isFrom => priceType == 'starting_from';

  /// What the price label should read on a card.
  String priceLabel(String Function(num) money) {
    if (isInspection) {
      return visitCharge > 0 ? '${money(visitCharge)} visit' : 'On inspection';
    }
    return isFrom ? 'From ${money(basePrice)}' : money(basePrice);
  }
}

/* ============================================================ ADDRESS */
class Address {
  final int id;
  final String label;
  final String? house;
  final String? area;
  final String? landmark;
  final String? city;
  final String? state;
  final String pincode;
  final double? lat;
  final double? lng;
  final bool isDefault;

  const Address({
    required this.id,
    required this.label,
    this.house,
    this.area,
    this.landmark,
    this.city,
    this.state,
    required this.pincode,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: _i(j['id']),
        label: j['label']?.toString() ?? 'Home',
        house: _s(j['house']),
        area: _s(j['area']),
        landmark: _s(j['landmark']),
        city: _s(j['city']),
        state: _s(j['state']),
        pincode: j['pincode']?.toString() ?? '',
        lat: j['lat'] == null ? null : _d(j['lat']),
        lng: j['lng'] == null ? null : _d(j['lng']),
        isDefault: j['is_default'] == true,
      );

  String get oneLine =>
      [house, area, landmark, city, pincode].where((e) => e != null && e!.isNotEmpty).join(', ');

  String get shortLine =>
      [area, city].where((e) => e != null && e!.isNotEmpty).join(', ');
}

/* ============================================================ CART */
class CartItem {
  final Service service;
  final ServiceOption? option;
  int qty;

  CartItem({required this.service, this.option, this.qty = 1});

  int get serviceId => service.id;
  int? get optionId => option?.id;

  String get title =>
      option == null ? service.name : '${service.name} · ${option!.name}';

  Map<String, dynamic> toRequest() => {
        'service_id': serviceId,
        if (optionId != null) 'option_id': optionId,
        'qty': qty,
      };

  Map<String, dynamic> toJson() => {
        'service': {
          'id': service.id,
          'category_id': service.categoryId,
          'name': service.name,
          'image_url': service.imageUrl,
          'base_price': service.basePrice,
          'price_type': service.priceType,
          'visit_charge': service.visitCharge,
          'duration_minutes': service.durationMinutes,
        },
        'option': option == null
            ? null
            : {'id': option!.id, 'name': option!.name, 'extra_price': option!.extraPrice},
        'qty': qty,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        service: Service.fromJson(Map<String, dynamic>.from(j['service'] as Map)),
        option: j['option'] == null
            ? null
            : ServiceOption.fromJson(Map<String, dynamic>.from(j['option'] as Map)),
        qty: _i(j['qty']),
      );
}

/// Server-calculated totals. The app never does this maths itself.
class PriceBreakup {
  final double subtotal;
  final double visitCharge;
  final double discount;
  final double tax;
  final double taxPercent;
  final double total;
  final double walletUsable;
  final bool couponApplied;
  final String? couponCode;
  final String? couponMessage;
  final int? couponId;
  final List<Map<String, dynamic>> lines;

  const PriceBreakup({
    this.subtotal = 0,
    this.visitCharge = 0,
    this.discount = 0,
    this.tax = 0,
    this.taxPercent = 0,
    this.total = 0,
    this.walletUsable = 0,
    this.couponApplied = false,
    this.couponCode,
    this.couponMessage,
    this.couponId,
    this.lines = const [],
  });

  factory PriceBreakup.fromJson(Map<String, dynamic> j) {
    final coupon = (j['coupon'] as Map?) ?? const {};
    return PriceBreakup(
      subtotal: _d(j['subtotal']),
      visitCharge: _d(j['visit_charge']),
      discount: _d(j['discount']),
      tax: _d(j['tax']),
      taxPercent: _d(j['tax_percent']),
      total: _d(j['total']),
      walletUsable: _d(j['wallet_usable']),
      couponApplied: coupon['applied'] == true,
      couponCode: _s(coupon['code']),
      couponMessage: _s(coupon['message']),
      couponId: coupon['id'] == null ? null : _i(coupon['id']),
      lines: (j['breakup_lines'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }
}

/* ============================================================ SLOTS */
class TimeSlot {
  final int id;
  final String label;
  final int remaining;
  final bool available;
  final String? reason;

  const TimeSlot({
    required this.id,
    required this.label,
    this.remaining = 0,
    this.available = false,
    this.reason,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> j) => TimeSlot(
        id: _i(j['id']),
        label: j['label']?.toString() ?? '',
        remaining: _i(j['remaining']),
        available: j['available'] == true,
        reason: _s(j['reason']),
      );
}

/* ============================================================ BOOKING */
class BookingSummary {
  final int id;
  final String code;
  final String status;
  final DateTime? scheduledDate;
  final String? slotLabel;
  final double total;
  final String paymentMode;
  final String paymentStatus;
  final String? services;
  final String? technicianName;
  final String? technicianPhoto;
  final bool hasReview;

  const BookingSummary({
    required this.id,
    required this.code,
    required this.status,
    this.scheduledDate,
    this.slotLabel,
    this.total = 0,
    this.paymentMode = 'cod',
    this.paymentStatus = 'pending',
    this.services,
    this.technicianName,
    this.technicianPhoto,
    this.hasReview = false,
  });

  factory BookingSummary.fromJson(Map<String, dynamic> j) => BookingSummary(
        id: _i(j['id']),
        code: j['booking_code']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        scheduledDate: DateTime.tryParse(j['scheduled_date']?.toString() ?? ''),
        slotLabel: _s(j['slot_label']),
        total: _d(j['total']),
        paymentMode: j['payment_mode']?.toString() ?? 'cod',
        paymentStatus: j['payment_status']?.toString() ?? 'pending',
        services: _s(j['services']),
        technicianName: _s(j['partner_name']),
        technicianPhoto: _s(j['partner_photo']),
        hasReview: j['has_review'] == true,
      );

  bool get isLive => StatusHelper.isLive(status);
}

class StatusHelper {
  static bool isLive(String s) => const [
        'confirmed',
        'assigned',
        'partner_on_the_way',
        'arrived',
        'in_progress',
      ].contains(s);
}

/* ============================================================ PARTS */
class Part {
  final int id;
  final String name;
  final String? sku;
  final String? description;
  final List<String> images;
  final double mrp;
  final double salePrice;
  final int stockQty;
  final String? brandName;
  final String? categoryName;
  final String? warrantyText;

  const Part({
    required this.id,
    required this.name,
    this.sku,
    this.description,
    this.images = const [],
    this.mrp = 0,
    this.salePrice = 0,
    this.stockQty = 0,
    this.brandName,
    this.categoryName,
    this.warrantyText,
  });

  factory Part.fromJson(Map<String, dynamic> j) => Part(
        id: _i(j['id']),
        name: j['name']?.toString() ?? '',
        sku: _s(j['sku']),
        description: _s(j['description']),
        images: _strList(j['images']),
        mrp: _d(j['mrp']),
        salePrice: _d(j['sale_price']),
        stockQty: _i(j['stock_qty']),
        brandName: _s(j['brand_name']),
        categoryName: _s(j['category_name']),
        warrantyText: _s(j['warranty_text']),
      );

  bool get inStock => stockQty > 0;
  bool get lowStock => stockQty > 0 && stockQty <= 5;
  int get discountPercent =>
      mrp > 0 ? (((mrp - salePrice) / mrp) * 100).round() : 0;
  String? get image => images.isNotEmpty ? images.first : null;
}

/* ============================================================ BANNER */
/// Named AppBanner to avoid colliding with Flutter's own Banner widget.
class AppBanner {
  final int id;
  final String imageUrl;
  final String? title;
  final String? targetType;
  final int? targetId;
  final String? targetUrl;

  const AppBanner({
    required this.id,
    required this.imageUrl,
    this.title,
    this.targetType,
    this.targetId,
    this.targetUrl,
  });

  factory AppBanner.fromJson(Map<String, dynamic> j) => AppBanner(
        id: _i(j['id']),
        imageUrl: j['image_url']?.toString() ?? '',
        title: _s(j['title']),
        targetType: _s(j['target_type']),
        targetId: j['target_id'] == null ? null : _i(j['target_id']),
        targetUrl: _s(j['target_url']),
      );
}
