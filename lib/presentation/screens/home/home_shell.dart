// lib/presentation/screens/home/home_shell.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/providers/config_provider.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../cart/cart_bar.dart';
import '../bookings/bookings_tab.dart';
import '../location/location_sheet.dart';
import 'home_tab.dart';

/// The four tabs a customer lives in. Bookings, Shop and Profile detail land
/// in the next batch — the placeholders below keep navigation honest.
class HomeShell extends StatefulWidget {
  final int initialTab;

  const HomeShell({super.key, this.initialTab = 0});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CartProvider>().restore();
      if (!mounted) return;

      // Without a pincode a customer cannot book anything, so ask once on the
      // first run rather than letting them hit a wall at checkout.
      final config = context.read<ConfigProvider>();
      if (!config.hasLocation) {
        await showLocationSheet(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final shopEnabled = config.partsShopEnabled;

    final tabs = <Widget>[
      const HomeTab(),
      const BookingsTab(),
      if (shopEnabled)
        const _ComingSoon(
          icon: Icons.storefront_rounded,
          title: 'Spare parts',
          message: 'Buy genuine parts with delivery to your door.',
        ),
      const _ProfileTab(),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long_outlined),
        activeIcon: Icon(Icons.receipt_long_rounded),
        label: 'Bookings',
      ),
      if (shopEnabled)
        const BottomNavigationBarItem(
          icon: Icon(Icons.storefront_outlined),
          activeIcon: Icon(Icons.storefront_rounded),
          label: 'Shop',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline_rounded),
        activeIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];

    final safeIndex = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: tabs),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The cart bar sits above the tabs so it survives tab switches.
          if (safeIndex == 0) const CartBar(),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.line)),
            ),
            child: BottomNavigationBar(
              currentIndex: safeIndex,
              onTap: (i) => setState(() => _index = i),
              items: items,
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------- stub */
class _ComingSoon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ComingSoon({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(icon: icon, title: 'Arriving soon', message: message),
    );
  }
}

/* ---------------------------------------------------------------- profile */
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final config = context.watch<ConfigProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user?.initial ?? 'U',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name?.trim().isNotEmpty == true
                            ? user!.name!
                            : 'Add your name',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.phone ?? '',
                        style: const TextStyle(
                            fontSize: 13.5, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _tile(
            context,
            Icons.location_on_outlined,
            'Service location',
            config.hasLocation
                ? '${config.city ?? ''} · ${config.pincode}'
                : 'Not set',
            () => showLocationSheet(context),
          ),
          _tile(
            context,
            Icons.account_balance_wallet_outlined,
            'Wallet',
            '₹${(user?.walletBalance ?? 0).toStringAsFixed(0)}',
            null,
          ),
          _tile(
            context,
            Icons.card_giftcard_outlined,
            'Refer and earn',
            user?.referralCode ?? '—',
            null,
          ),
          if (config.supportPhone.isNotEmpty)
            _tile(
              context,
              Icons.support_agent_rounded,
              'Help and support',
              config.supportPhone,
              null,
            ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () async {
              final yes = await confirmSheet(
                context,
                title: 'Sign out?',
                message: 'You will need to verify your number again to book.',
                confirmLabel: 'Sign out',
                danger: true,
              );
              if (!yes || !context.mounted) return;

              await context.read<AuthProvider>().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 19),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
          ),

          const SizedBox(height: 20),
          Center(
            child: Text(
              '${config.brandName} · v1.0.0',
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String value,
    VoidCallback? onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 21, color: AppTheme.muted),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 13, color: AppTheme.muted),
        ),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
