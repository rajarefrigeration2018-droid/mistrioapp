// lib/presentation/screens/home/home_tab.dart

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/config_provider.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/service_card.dart';
import '../location/location_sheet.dart';
import '../service/service_detail_screen.dart';
import 'category_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _repo = CatalogRepository.instance;

  HomeData? _data;
  String? _error;
  bool _loading = true;
  int _bannerIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = _data == null;
      _error = null;
    });

    try {
      final pincode = context.read<ConfigProvider>().pincode;
      final data = await _repo.home(pincode: pincode);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(config, user)),

              if (_loading)
                const SliverToBoxAdapter(child: _HomeSkeleton())
              else if (_error != null && _data == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(message: _error!, onRetry: _load),
                )
              else ...[
                if (_data!.banners.isNotEmpty)
                  SliverToBoxAdapter(child: _banners(_data!.banners)),

                if (_data!.categories.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: SectionTitle(title: 'What needs fixing?'),
                    ),
                  ),
                  SliverToBoxAdapter(child: _categories(_data!.categories)),
                ],

                if (_data!.offers.isNotEmpty)
                  SliverToBoxAdapter(child: _offers(_data!.offers)),

                if (_data!.popular.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: SectionTitle(title: 'Booked most often'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    sliver: SliverList.separated(
                      itemCount: _data!.popular.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => ServiceCard(service: _data!.popular[i]),
                    ),
                  ),
                ],

                if (_data!.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.handyman_rounded,
                      title: 'Nothing to show yet',
                      message: 'Services will appear here once they are added.',
                    ),
                  ),

                SliverToBoxAdapter(child: _trust(config)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /* ---------------------------------------------------------------- header */
  Widget _header(ConfigProvider config, AppUser? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    await showLocationSheet(context);
                    if (mounted) _load();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 18, color: config.accentColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            config.hasLocation
                                ? '${config.city ?? 'Your area'} · ${config.pincode}'
                                : 'Set your location',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        const Icon(Icons.expand_more_rounded,
                            size: 18, color: AppTheme.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            user.greeting,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Trained technicians, upfront pricing.',
            style: TextStyle(color: AppTheme.muted, fontSize: 14.5),
          ),
          const SizedBox(height: 14),
          _search(),
        ],
      ),
    );
  }

  Widget _search() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CategoryScreen.search()),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: AppTheme.muted),
            SizedBox(width: 10),
            Text(
              'Search AC service, fridge repair…',
              style: TextStyle(color: AppTheme.muted, fontSize: 14.5),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------------------------------------------------------------- banners */
  Widget _banners(List<AppBanner> banners) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: 150,
              viewportFraction: 0.9,
              autoPlay: banners.length > 1,
              autoPlayInterval: const Duration(seconds: 5),
              enableInfiniteScroll: banners.length > 1,
              onPageChanged: (i, _) => setState(() => _bannerIndex = i),
            ),
            items: banners
                .map((b) => GestureDetector(
                      onTap: () => _openBanner(b),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AppImage(
                          url: b.imageUrl,
                          width: double.infinity,
                          height: 150,
                          radius: 14,
                          fallbackIcon: Icons.image_rounded,
                        ),
                      ),
                    ))
                .toList(),
          ),
          if (banners.length > 1) ...[
            const SizedBox(height: 10),
            AnimatedSmoothIndicator(
              activeIndex: _bannerIndex,
              count: banners.length,
              effect: ExpandingDotsEffect(
                dotHeight: 6,
                dotWidth: 6,
                expansionFactor: 3,
                activeDotColor: Theme.of(context).colorScheme.primary,
                dotColor: AppTheme.line,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openBanner(AppBanner b) {
    if (b.targetType == 'service' && b.targetId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(serviceId: b.targetId!),
        ),
      );
    } else if (b.targetType == 'category' && b.targetId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryScreen(
            categoryId: b.targetId!,
            title: b.title ?? 'Services',
          ),
        ),
      );
    }
  }

  /* ---------------------------------------------------------------- grid */
  Widget _categories(List<Category> categories) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.92,
        ),
        itemBuilder: (_, i) {
          final c = categories[i];
          return InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryScreen(categoryId: c.id, title: c.name),
              ),
            ),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppImage(
                    url: c.iconUrl,
                    width: 42,
                    height: 42,
                    radius: 10,
                    fallbackIcon: Icons.ac_unit_rounded,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /* ---------------------------------------------------------------- offers */
  Widget _offers(List<Map<String, dynamic>> offers) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Offers for you'),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final o = offers[i];
                final isPercent = o['type'] == 'percent';
                final value = (o['value'] as num?)?.toDouble() ?? 0;
                return Container(
                  width: 230,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: 0.1),
                    border: Border.all(color: AppTheme.amber.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPercent
                            ? '${value.toStringAsFixed(0)}% off'
                            : '${Fmt.money(value)} off',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        o['title']?.toString() ??
                            'Use code ${o['code'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
                      ),
                      const Spacer(),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.line),
                        ),
                        child: Text(
                          o['code']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------------------------------------------------------- trust */
  Widget _trust(ConfigProvider config) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            _trustRow(
              Icons.verified_user_rounded,
              'Verified technicians',
              'Every technician is checked before their first job.',
            ),
            const Divider(height: 22),
            _trustRow(
              Icons.receipt_long_rounded,
              'No surprise charges',
              'Extra parts need your approval in the app before they are billed.',
            ),
            const Divider(height: 22),
            _trustRow(
              Icons.shield_rounded,
              'Work is under warranty',
              'Covered repairs are redone free within the warranty period.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _trustRow(IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(body,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppTheme.muted, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tiny adapter so the header does not care whether a user is loaded yet.
extension AppUserLike on AppUser? {
  String get greeting {
    final name = this?.name?.trim();
    if (name == null || name.isEmpty) return 'What can we fix today?';
    final first = name.split(' ').first;
    return 'Hi $first, what needs fixing?';
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Shim(height: 150, radius: 14),
          const SizedBox(height: 24),
          const Shim(width: 160, height: 20),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
            children: List.generate(6, (_) => const Shim(height: 100, radius: 14)),
          ),
          const SizedBox(height: 24),
          const Shim(width: 180, height: 20),
          const SizedBox(height: 14),
          ...List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Shim(height: 100, radius: 14),
            ),
          ),
        ],
      ),
    );
  }
}
