import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Global app state: remote config, session, active loan and notifications count.
class AppState extends ChangeNotifier {
  final api = Api.instance;

  Map<String, dynamic> settings = {};
  List<Map<String, dynamic>> banners = [];
  Map<String, dynamic>? user;
  Map<String, dynamic>? loan; // active loan (draft / submitted / ... / disbursed)
  int unread = 0;
  bool onboarded = false;
  bool consentGiven = false;
  String appVersion = '1.0.0';
  Map<String, dynamic> device = {};

  bool get loggedIn => user != null && api.token != null;

  Map<String, dynamic> get loanConfig => Map<String, dynamic>.from(settings['loan'] ?? {});
  Map<String, dynamic> get support => Map<String, dynamic>.from(settings['support'] ?? {});
  Map<String, dynamic> get legal => Map<String, dynamic>.from(settings['legal'] ?? {});
  Map<String, dynamic> get repayment => Map<String, dynamic>.from(settings['repayment'] ?? {});
  Map<String, dynamic> get appInfo => Map<String, dynamic>.from(settings['app'] ?? {});

  List<String> options(String key) => List<String>.from((settings['options'] ?? {})[key] ?? const []);

  /// Active loan categories configured in the admin panel.
  List<Map<String, dynamic>> get products => List<Map<String, dynamic>>.from(settings['products'] ?? const []);

  Map<String, dynamic>? product(String? key) {
    for (final p in products) {
      if (p['key'] == key) return p;
    }
    return products.isEmpty ? null : products.first;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    onboarded = prefs.getBool('onboarded') ?? false;
    consentGiven = prefs.getBool('consent') ?? false;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
    } catch (_) {}
    await _readDevice();
    api.onUnauthorized = () {
      user = null;
      loan = null;
      api.setToken(null);
      notifyListeners();
    };
    await api.loadToken();
  }

  Future<void> _readDevice() async {
    device = {'os': kIsWeb ? 'web' : 'unknown', 'appVersion': appVersion};
    if (kIsWeb) return;
    try {
      final di = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await di.androidInfo;
        device = {'brand': a.brand, 'model': a.model, 'os': 'android', 'osVersion': a.version.release, 'deviceId': a.id, 'appVersion': appVersion};
      }
    } catch (_) {
      // keep the fallback set above
    }
  }

  Future<void> loadConfig() async {
    final r = await api.get('/app/config');
    settings = Map<String, dynamic>.from(r['data']['settings']);
    banners = List<Map<String, dynamic>>.from(r['data']['banners'] ?? []);
    notifyListeners();
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    (await SharedPreferences.getInstance()).setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> setConsent() async {
    consentGiven = true;
    (await SharedPreferences.getInstance()).setBool('consent', true);
    notifyListeners();
  }

  Future<List<String>> grantedPermissions() async {
    final out = <String>[];
    try {
      if (await Permission.camera.isGranted) out.add('camera');
      if (await Permission.locationWhenInUse.isGranted) out.add('location');
      if (await Permission.notification.isGranted) out.add('notification');
    } catch (_) {}
    return out;
  }

  /* ---------------------------------------------------------- session */

  Future<bool> restoreSession() async {
    if (api.token == null) return false;
    try {
      final r = await api.get('/auth/me');
      user = Map<String, dynamic>.from(r['data']['user']);
      await refreshLoan();
      _pingDevice();
      refreshUnread();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Requests an OTP. In demo mode the response contains `otp` so it can be shown on screen.
  Future<Map<String, dynamic>> sendOtp(String mobile) async {
    final r = await api.post('/auth/otp/send', {'mobile': mobile});
    return Map<String, dynamic>.from(r['data']);
  }

  Future<void> verifyOtp(String mobile, String otp) async {
    final r = await api.post('/auth/otp/verify', {
      'mobile': mobile,
      'otp': otp,
      'device': device,
      'consent': {'termsAccepted': true, 'privacyAccepted': true, 'permissions': await grantedPermissions()},
    });
    await _afterAuth(r['data']);
  }

  Future<void> _afterAuth(Map data) async {
    await api.setToken(data['token']);
    user = Map<String, dynamic>.from(data['user']);
    await refreshLoan();
    _pingDevice();
    refreshUnread();
    notifyListeners();
  }

  Future<void> logout() async {
    await api.setToken(null);
    user = null;
    loan = null;
    unread = 0;
    notifyListeners();
  }

  /// Sends device details and (only if the user allowed it) approximate location.
  Future<void> _pingDevice() async {
    try {
      final body = <String, dynamic>{...device, 'permissions': await grantedPermissions()};
      if (await Permission.locationWhenInUse.isGranted && await Geolocator.isLocationServiceEnabled()) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
        );
        body['latitude'] = pos.latitude;
        body['longitude'] = pos.longitude;
      }
      await api.put('/auth/device', body);
    } catch (_) {}
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final r = await api.put('/auth/profile', data);
    user = Map<String, dynamic>.from(r['data']['user']);
    notifyListeners();
  }

  /* ---------------------------------------------------------- loan */

  Future<void> refreshLoan() async {
    final r = await api.get('/loans/current');
    final l = r['data']['loan'];
    loan = l == null ? null : Map<String, dynamic>.from(l);
    notifyListeners();
  }

  void setLoan(dynamic l) {
    loan = l == null ? null : Map<String, dynamic>.from(l);
    notifyListeners();
  }

  Future<void> refreshUnread() async {
    try {
      final r = await api.get('/notifications');
      unread = (r['data']['unread'] ?? 0) as int;
      notifyListeners();
    } catch (_) {}
  }

  /// Compares semantic versions "1.2.3".
  static int compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  bool get mustUpdate => compareVersions(appVersion, '${appInfo['minVersion'] ?? '0.0.0'}') < 0;
  bool get canUpdate => compareVersions(appVersion, '${appInfo['latestVersion'] ?? '0.0.0'}') < 0;

  @visibleForTesting
  void debugSet({Map<String, dynamic>? settings}) {
    if (settings != null) this.settings = settings;
  }
}
