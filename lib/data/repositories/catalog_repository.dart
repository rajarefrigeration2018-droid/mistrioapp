// lib/data/repositories/catalog_repository.dart

import '../../core/api/api_client.dart';
import '../models/models.dart';

class HomeData {
  final List<AppBanner> banners;
  final List<Category> categories;
  final List<Service> popular;
  final List<Map<String, dynamic>> offers;

  const HomeData({
    this.banners = const [],
    this.categories = const [],
    this.popular = const [],
    this.offers = const [],
  });

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        banners: ((j['banners'] as List?) ?? [])
            .map((e) => AppBanner.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        categories: ((j['categories'] as List?) ?? [])
            .map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        popular: ((j['popular_services'] as List?) ?? [])
            .map((e) => Service.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        offers: ((j['offers'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );

  bool get isEmpty => categories.isEmpty && popular.isEmpty;
}

class CatalogRepository {
  CatalogRepository._();
  static final CatalogRepository instance = CatalogRepository._();

  final _api = ApiClient.instance;

  Future<HomeData> home({String? pincode}) async {
    final data = await _api.get('/home', query: {if (pincode != null) 'pincode': pincode});
    return HomeData.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<Category>> categories() async {
    final data = await _api.get('/categories');
    return (data as List)
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Service>> services({int? categoryId, String? search}) async {
    final data = await _api.get('/services', query: {
      if (categoryId != null) 'category_id': categoryId,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (data as List)
        .map((e) => Service.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Service> service(int id) async {
    final data = await _api.get('/services/$id');
    return Service.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<TimeSlot>> slots(DateTime date) async {
    final iso = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final data = await _api.get('/slots', query: {'date': iso});
    return ((data['slots'] as List?) ?? [])
        .map((e) => TimeSlot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Server-calculated cart total. The app never adds these numbers itself.
  Future<PriceBreakup> pricePreview({
    required List<Map<String, dynamic>> items,
    String? couponCode,
    bool useWallet = false,
  }) async {
    final data = await _api.post('/price-preview', body: {
      'items': items,
      if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
      'use_wallet': useWallet,
    });
    return PriceBreakup.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
