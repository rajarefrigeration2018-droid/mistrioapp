// lib/presentation/screens/location/location_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/config_provider.dart';
import '../../widgets/common.dart';

/// Opens the location picker. Returns true if a serviceable pincode was set.
Future<bool> showLocationSheet(BuildContext context, {bool dismissible = true}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _LocationSheet(dismissible: dismissible),
  );
  return result ?? false;
}

class _LocationSheet extends StatefulWidget {
  final bool dismissible;

  const _LocationSheet({required this.dismissible});

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _pincode = TextEditingController();

  bool _checking = false;
  bool _locating = false;
  String? _message;
  bool _notServiceable = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<ConfigProvider>().pincode;
    if (current != null) _pincode.text = current;
  }

  @override
  void dispose() {
    _pincode.dispose();
    super.dispose();
  }

  /* ---------------------------------------------------------------- check */
  Future<void> _check(String pincode) async {
    if (pincode.length != 6) {
      setState(() => _message = 'Enter a 6-digit pincode');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _message = null;
      _notServiceable = false;
    });

    final config = context.read<ConfigProvider>();
    final ok = await config.checkServiceable(pincode);

    if (!mounted) return;
    setState(() => _checking = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _notServiceable = true;
        _message = 'We do not serve $pincode yet.';
      });
    }
  }

  /* ---------------------------------------------------------------- gps */
  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _message = null;
      _notServiceable = false;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _fail('Turn on location services and try again.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _fail('Location permission is needed to detect your area.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _fail('Location is blocked. Enable it in your phone settings, or type '
            'your pincode below.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (places.isEmpty || (places.first.postalCode ?? '').isEmpty) {
        _fail('Could not read your pincode. Please type it below.');
        return;
      }

      final pincode = places.first.postalCode!.replaceAll(RegExp(r'\D'), '');
      if (!mounted) return;

      _pincode.text = pincode;
      setState(() => _locating = false);
      await _check(pincode);
    } catch (_) {
      _fail('Could not detect your location. Please type your pincode.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _locating = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final cities = config.cities;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Where do you need service?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (widget.dismissible)
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'We only take bookings in areas our technicians cover.',
                style: TextStyle(fontSize: 14, color: AppTheme.muted, height: 1.4),
              ),

              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.my_location_rounded,
                        size: 19, color: Theme.of(context).colorScheme.primary),
                label: Text(_locating ? 'Detecting…' : 'Use my current location'),
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or enter pincode',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.muted.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pincode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 17, letterSpacing: 1.5),
                      decoration: const InputDecoration(
                        hintText: '141001',
                        counterText: '',
                        prefixIcon: Icon(Icons.pin_drop_outlined, size: 20),
                      ),
                      onSubmitted: _check,
                      onChanged: (_) {
                        if (_message != null) setState(() => _message = null);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          _checking ? null : () => _check(_pincode.text.trim()),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(88, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Check'),
                    ),
                  ),
                ],
              ),

              if (_message != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: (_notServiceable ? AppTheme.warn : AppTheme.danger)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _notServiceable
                            ? Icons.location_off_rounded
                            : Icons.error_outline_rounded,
                        size: 18,
                        color: _notServiceable ? AppTheme.warn : AppTheme.danger,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _message!,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: _notServiceable
                                    ? AppTheme.warn
                                    : AppTheme.danger,
                              ),
                            ),
                            if (_notServiceable && cities.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'We are expanding fast — check back soon.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.warn.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (cities.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Text(
                  'CITIES WE SERVE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cities
                      .map((c) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppTheme.paper,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              c['city']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact banner shown on Home when no location has been picked yet.
class LocationPrompt extends StatelessWidget {
  const LocationPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, size: 20, color: AppTheme.amber),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Set your location to see if we cover your area.',
              style: TextStyle(fontSize: 13.5, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: () => showLocationSheet(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
            ),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
