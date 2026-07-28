// lib/data/providers/auth_provider.dart

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../models/models.dart';

enum AuthState { unknown, signedOut, signedIn }

/// Firebase runs the OTP on the device; our backend verifies the resulting
/// ID token and issues its own JWT. The Firebase session is only a means to
/// prove the phone number — everything after login uses our token.
class AuthProvider extends ChangeNotifier {
  final _api = ApiClient.instance;
  final _firebase = fb.FirebaseAuth.instance;

  AuthState _state = AuthState.unknown;
  AppUser? _user;
  String? _error;
  bool _busy = false;

  // OTP flow
  String? _verificationId;
  int? _resendToken;
  String _pendingPhone = '';
  bool _codeSent = false;
  bool _autoVerified = false;

  // ---------------------------------------------------------------- getters
  AuthState get state => _state;
  AppUser? get user => _user;
  String? get error => _error;
  bool get busy => _busy;
  bool get codeSent => _codeSent;
  bool get autoVerified => _autoVerified;
  String get pendingPhone => _pendingPhone;
  bool get isSignedIn => _state == AuthState.signedIn && _user != null;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Sends the login screen back to the phone-entry step without firing a
  /// request. Used by the back arrow on the OTP step.
  void resetOtpFlow() {
    _codeSent = false;
    _autoVerified = false;
    _verificationId = null;
    _error = null;
    _busy = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- restore
  Future<void> restore() async {
    await _api.restoreSession();

    if (!_api.hasToken) {
      _state = AuthState.signedOut;
      notifyListeners();
      return;
    }

    // Show the cached user immediately, then refresh in the background.
    await _loadCachedUser();
    _state = AuthState.signedIn;
    notifyListeners();

    try {
      final data = await _api.get('/auth/user/me');
      _user = AppUser.fromJson(Map<String, dynamic>.from(data as Map));
      await _cacheUser();
      _state = AuthState.signedIn;
    } on ApiException catch (e) {
      if (e.isAuth) {
        await signOut();
      }
      // On a network error we keep the cached user — offline should not log out.
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- send OTP
  Future<void> sendOtp(String phone, {bool resend = false}) async {
    _busy = true;
    _error = null;
    _codeSent = false;
    _autoVerified = false;
    _pendingPhone = phone;
    notifyListeners();

    try {
      await _firebase.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend ? _resendToken : null,

        // Android can read the SMS itself — sign in without the user typing.
        verificationCompleted: (credential) async {
          _autoVerified = true;
          notifyListeners();
          await _signInWithCredential(credential);
        },

        verificationFailed: (e) {
          _busy = false;
          _error = _firebaseMessage(e);
          notifyListeners();
        },

        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSent = true;
          _busy = false;
          notifyListeners();
        },

        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _busy = false;
      _error = 'Could not send the code. Please try again.';
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- verify
  Future<bool> verifyOtp(String smsCode, {String? referralCode}) async {
    if (_verificationId == null) {
      _error = 'Request a new code first.';
      notifyListeners();
      return false;
    }

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      return await _signInWithCredential(credential, referralCode: referralCode);
    } on fb.FirebaseAuthException catch (e) {
      _busy = false;
      _error = _firebaseMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> _signInWithCredential(
    fb.PhoneAuthCredential credential, {
    String? referralCode,
  }) async {
    try {
      final result = await _firebase.signInWithCredential(credential);
      final idToken = await result.user?.getIdToken();

      if (idToken == null) {
        _busy = false;
        _error = 'Sign-in failed. Please try again.';
        notifyListeners();
        return false;
      }

      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {
        // Push is a bonus, not a blocker.
      }

      final data = await _api.post('/auth/user/firebase', body: {
        'id_token': idToken,
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode,
      });

      await _api.setToken(data['token'] as String);
      _user = AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
      await _cacheUser();

      _state = AuthState.signedIn;
      _busy = false;
      _codeSent = false;
      _verificationId = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _busy = false;
      _error = e.message;
      notifyListeners();
      return false;
    } on fb.FirebaseAuthException catch (e) {
      _busy = false;
      _error = _firebaseMessage(e);
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------- profile
  Future<bool> updateProfile({String? name, String? email, String? image}) async {
    _busy = true;
    notifyListeners();
    try {
      final data = await _api.put('/auth/user/me', body: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (image != null) 'profile_image': image,
      });
      _user = AppUser.fromJson(Map<String, dynamic>.from(data as Map));
      await _cacheUser();
      _busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _busy = false;
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshUser() async {
    try {
      final data = await _api.get('/auth/user/me');
      _user = AppUser.fromJson(Map<String, dynamic>.from(data as Map));
      await _cacheUser();
      notifyListeners();
    } on ApiException {
      // Silent — this runs in the background.
    }
  }

  /// Called after a wallet change so the balance on screen stays honest.
  void setWalletBalance(double balance) {
    if (_user == null) return;
    _user = AppUser(
      id: _user!.id,
      phone: _user!.phone,
      name: _user!.name,
      email: _user!.email,
      profileImage: _user!.profileImage,
      referralCode: _user!.referralCode,
      walletBalance: balance,
      profileComplete: _user!.profileComplete,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------- sign out
  Future<void> signOut() async {
    await _api.clearToken();
    try {
      await _firebase.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.kUser);
    await prefs.remove(AppConstants.kCart);

    _user = null;
    _state = AuthState.signedOut;
    _codeSent = false;
    _verificationId = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    try {
      await _api.delete('/auth/user/me');
      await signOut();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------- cache
  Future<void> _cacheUser() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.kUser, jsonEncode(_user!.toJson()));
  }

  Future<void> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.kUser);
      if (raw == null) return;
      _user = AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {}
  }

  // ---------------------------------------------------------------- errors
  String _firebaseMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'That phone number does not look right.';
      case 'invalid-verification-code':
        return 'Wrong code. Check the SMS and try again.';
      case 'session-expired':
        return 'The code expired. Request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      case 'quota-exceeded':
        return 'We cannot send codes right now. Please try later.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'app-not-authorized':
        return 'This app build is not authorised. Contact support.';
      default:
        return e.message ?? 'Sign-in failed. Please try again.';
    }
  }
}
