// lib/presentation/screens/splash/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/config_provider.dart';
import '../../../main.dart';
import '../auth/login_screen.dart';
import '../home/home_shell.dart';

/// Boots the app: loads config, checks for a forced update or maintenance,
/// restores the session, then sends the user where they belong.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = '';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    setState(() {
      _failed = false;
      _status = '';
    });

    final config = context.read<ConfigProvider>();
    final auth = context.read<AuthProvider>();

    String? version;
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}

    await Future.wait([
      config.load(appVersion: version),
      config.restoreLocation(),
      auth.restore(),
    ]);

    if (!mounted) return;

    // Could not reach the server and have nothing cached — offer a retry
    // rather than dropping the user into an empty app.
    if (!config.loadedFromServer && config.error != null) {
      setState(() {
        _failed = true;
        _status = config.error!;
      });
      return;
    }

    if (config.forceUpdate && config.updateRequired) {
      _replace(BlockingScreen(
        icon: Icons.system_update_rounded,
        title: 'Update required',
        message: config.updateMessage.isEmpty
            ? 'A newer version is available. Update to continue.'
            : config.updateMessage,
        actionLabel: 'Update now',
        onAction: _openStore,
      ));
      return;
    }

    if (config.maintenance) {
      _replace(BlockingScreen(
        icon: Icons.build_rounded,
        title: 'Back shortly',
        message: config.maintenanceMessage.isEmpty
            ? 'We are carrying out maintenance. Please check back soon.'
            : config.maintenanceMessage,
        actionLabel: 'Try again',
        onAction: _boot,
      ));
      return;
    }

    _replace(auth.isSignedIn ? const HomeShell() : const LoginScreen());
  }

  void _replace(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.mistrio.user',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();

    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _Mark(),
                const SizedBox(height: 22),
                Text(
                  config.brandName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                if (config.tagline.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    config.tagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                  ),
                ],
                const SizedBox(height: 44),
                if (_failed) ...[
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Shown so a failed connection can be diagnosed without a
                  // debugger. Remove this block before the public release.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TRYING TO REACH',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          AppConstants.apiBaseUrl,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: _boot,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.amber,
                      side: const BorderSide(color: AppTheme.amber),
                      minimumSize: const Size(160, 46),
                    ),
                    child: const Text('Try again'),
                  ),
                ] else
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(AppTheme.amber),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppTheme.amber,
        borderRadius: BorderRadius.circular(22),
      ),
      alignment: Alignment.center,
      child: const Text(
        'M',
        style: TextStyle(
          color: AppTheme.ink,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
