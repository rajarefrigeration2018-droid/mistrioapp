// lib/presentation/screens/auth/login_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/config_provider.dart';
import '../home/home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _referral = TextEditingController();
  final _otpFocus = FocusNode();

  bool _showReferral = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _referral.dispose();
    _otpFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _send({bool resend = false}) async {
    final phone = _phone.text.trim();
    if (phone.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      _snack('Enter a valid 10-digit mobile number');
      return;
    }

    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    await auth.sendOtp(phone, resend: resend);

    if (!mounted) return;
    if (auth.error != null) {
      _snack(auth.error!);
      auth.clearError();
      return;
    }
    if (auth.codeSent) {
      _startResendTimer();
      Future.delayed(
        const Duration(milliseconds: 250),
        () => _otpFocus.requestFocus(),
      );
    }
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (code.length < 6) {
      _snack('Enter the 6-digit code');
      return;
    }

    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(
      code,
      referralCode: _referral.text.trim().isEmpty ? null : _referral.text.trim(),
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } else if (auth.error != null) {
      _snack(auth.error!);
      auth.clearError();
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final config = context.watch<ConfigProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.vertical -
                    36,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (auth.codeSent)
                    IconButton(
                      onPressed: auth.busy
                          ? null
                          : () {
                              _otp.clear();
                              _timer?.cancel();
                              setState(() => _resendIn = 0);
                              context.read<AuthProvider>().resetOtpFlow();
                            },
                      icon: const Icon(Icons.arrow_back),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    )
                  else
                    const SizedBox(height: 40),

                  const SizedBox(height: 20),

                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: config.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'M',
                      style: TextStyle(
                        color: config.accentColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  Text(
                    auth.codeSent ? 'Enter the code' : 'Your appliances, sorted',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth.codeSent
                        ? 'Sent to +91 ${auth.pendingPhone}'
                        : 'AC, fridge and washing machine service at your door.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: AppTheme.muted),
                  ),

                  const SizedBox(height: 32),

                  if (!auth.codeSent) ..._phoneStep(auth) else ..._otpStep(auth),

                  const Spacer(),

                  const SizedBox(height: 28),
                  _legal(config),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- step 1
  List<Widget> _phoneStep(AuthProvider auth) => [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofocus: true,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 18, letterSpacing: 0.5),
          decoration: InputDecoration(
            hintText: '98765 43210',
            counterText: '',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8, top: 15),
              child: Text(
                '+91',
                style: TextStyle(
                  fontSize: 18,
                  color: AppTheme.ink.withValues(alpha: 0.7),
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
          ),
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 14),

        if (_showReferral)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              controller: _referral,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'Referral code'),
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showReferral = true),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Have a referral code?'),
            ),
          ),

        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: auth.busy ? null : () => _send(),
          child: auth.busy
              ? const _Spinner()
              : const Text('Send verification code'),
        ),
        const SizedBox(height: 12),
        const Text(
          'We will send a 6-digit code to confirm your number.',
          style: TextStyle(fontSize: 13, color: AppTheme.muted),
        ),
      ];

  // ---------------------------------------------------------------- step 2
  List<Widget> _otpStep(AuthProvider auth) => [
        if (auth.autoVerified)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.ok.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.ok, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Code detected. Signing you in…',
                    style: TextStyle(color: AppTheme.ok, fontSize: 14),
                  ),
                ),
              ],
            ),
          )
        else ...[
          TextField(
            controller: _otp,
            focusNode: _otpFocus,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 26,
              letterSpacing: 12,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              hintText: '······',
              counterText: '',
              hintStyle: TextStyle(letterSpacing: 12, fontSize: 26),
            ),
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: auth.busy ? null : _verify,
            child: auth.busy ? const _Spinner() : const Text('Verify and continue'),
          ),
          const SizedBox(height: 14),
          Center(
            child: _resendIn > 0
                ? Text(
                    'Resend code in ${_resendIn}s',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 14),
                  )
                : TextButton(
                    onPressed: auth.busy ? null : () => _send(resend: true),
                    child: const Text('Resend code'),
                  ),
          ),
        ],
      ];

  // ---------------------------------------------------------------- legal
  Widget _legal(ConfigProvider config) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'By continuing you agree to our ',
            style: TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          _link('Terms', config.termsUrl),
          const Text(
            ' and ',
            style: TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          _link('Privacy Policy', config.privacyUrl),
        ],
      ),
    );
  }

  Widget _link(String label, String url) {
    return GestureDetector(
      onTap: url.isEmpty
          ? null
          : () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      );
}
