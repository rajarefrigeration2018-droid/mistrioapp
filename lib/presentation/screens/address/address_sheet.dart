// lib/presentation/screens/address/address_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/config_provider.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../widgets/common.dart';

/// Add or edit an address. Returns the saved Address, or null if dismissed.
Future<Address?> showAddressSheet(BuildContext context, {Address? existing}) {
  return showModalBottomSheet<Address>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddressSheet(existing: existing),
  );
}

class _AddressSheet extends StatefulWidget {
  final Address? existing;

  const _AddressSheet({this.existing});

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  final _repo = BookingRepository.instance;

  final _house = TextEditingController();
  final _area = TextEditingController();
  final _landmark = TextEditingController();
  final _pincode = TextEditingController();
  final _city = TextEditingController();

  String _label = 'Home';
  double? _lat;
  double? _lng;

  bool _saving = false;
  bool _locating = false;
  String? _error;

  static const _labels = ['Home', 'Work', 'Other'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _label = _labels.contains(e.label) ? e.label : 'Other';
      _house.text = e.house ?? '';
      _area.text = e.area ?? '';
      _landmark.text = e.landmark ?? '';
      _pincode.text = e.pincode;
      _city.text = e.city ?? '';
      _lat = e.lat;
      _lng = e.lng;
    } else {
      final config = context.read<ConfigProvider>();
      _pincode.text = config.pincode ?? '';
      _city.text = config.city ?? '';
    }
  }

  @override
  void dispose() {
    _house.dispose();
    _area.dispose();
    _landmark.dispose();
    _pincode.dispose();
    _city.dispose();
    super.dispose();
  }

  /* ---------------------------------------------------------------- gps */
  Future<void> _detect() async {
    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _fail('Turn on location services first.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _fail('Location permission denied. Fill the address manually.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final places = await placemarkFromCoordinates(pos.latitude, pos.longitude);

      if (!mounted) return;
      if (places.isNotEmpty) {
        final p = places.first;
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          if ((p.subLocality ?? '').isNotEmpty && _area.text.isEmpty) {
            _area.text = p.subLocality!;
          } else if ((p.locality ?? '').isNotEmpty && _area.text.isEmpty) {
            _area.text = p.locality!;
          }
          if ((p.postalCode ?? '').isNotEmpty) {
            _pincode.text = p.postalCode!.replaceAll(RegExp(r'\D'), '');
          }
          if ((p.locality ?? '').isNotEmpty) _city.text = p.locality!;
          _locating = false;
        });
      } else {
        _fail('Could not read your address. Please type it in.');
      }
    } catch (_) {
      _fail('Could not detect your location. Please type the address.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _locating = false;
      _error = message;
    });
  }

  /* ---------------------------------------------------------------- save */
  Future<void> _save() async {
    final pincode = _pincode.text.trim();

    if (_house.text.trim().isEmpty) {
      setState(() => _error = 'Add the house or flat number');
      return;
    }
    if (_area.text.trim().isEmpty) {
      setState(() => _error = 'Add the area or locality');
      return;
    }
    if (pincode.length != 6) {
      setState(() => _error = 'Enter a valid 6-digit pincode');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final Address saved;
      if (widget.existing == null) {
        saved = await _repo.createAddress(
          label: _label,
          house: _house.text.trim(),
          area: _area.text.trim(),
          landmark: _landmark.text.trim(),
          city: _city.text.trim(),
          pincode: pincode,
          lat: _lat,
          lng: _lng,
        );
      } else {
        saved = await _repo.updateAddress(widget.existing!.id, {
          'label': _label,
          'house': _house.text.trim(),
          'area': _area.text.trim(),
          'landmark': _landmark.text.trim(),
          'city': _city.text.trim(),
          'pincode': pincode,
          'lat': _lat,
          'lng': _lng,
          'is_default': widget.existing!.isDefault,
        });
      }

      if (!mounted) return;
      Navigator.pop(context, saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      widget.existing == null ? 'Add address' : 'Edit address',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _locating ? null : _detect,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.my_location_rounded,
                        size: 18, color: Theme.of(context).colorScheme.primary),
                label: Text(_locating ? 'Detecting…' : 'Use my current location'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: _labels.map((l) {
                  final on = _label == l;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l),
                      selected: on,
                      onSelected: (_) => setState(() => _label = l),
                      selectedColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        fontSize: 13.5,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                        color: on
                            ? Theme.of(context).colorScheme.primary
                            : AppTheme.ink,
                      ),
                      side: BorderSide(
                        color: on
                            ? Theme.of(context).colorScheme.primary
                            : AppTheme.line,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              _field(_house, 'House / flat number', Icons.home_outlined,
                  autofocus: widget.existing == null),
              const SizedBox(height: 12),
              _field(_area, 'Area or locality', Icons.map_outlined),
              const SizedBox(height: 12),
              _field(_landmark, 'Landmark (optional)', Icons.place_outlined),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _field(_city, 'City', Icons.location_city_outlined),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _pincode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 18, color: AppTheme.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              fontSize: 13.5, color: AppTheme.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(widget.existing == null ? 'Save address' : 'Update address'),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        isDense: true,
      ),
    );
  }
}

/// Compact address row used in the picker and the address list.
class AddressTile extends StatelessWidget {
  final Address address;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const AddressTile({
    super.key,
    required this.address,
    this.selected = false,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: selected ? primary : AppTheme.line,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 10),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? primary : AppTheme.muted,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address.label,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 6),
                        const Pill(label: 'Default'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address.oneLine,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.muted, height: 1.4),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
