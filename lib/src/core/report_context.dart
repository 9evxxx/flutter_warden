import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Device and app context for error reports.
class ReportContext {
  const ReportContext({
    this.platform,
    this.osVersion,
    this.deviceModel,
    this.deviceBrand,
    this.appName,
    this.appVersion,
    this.appBuildNumber,
    this.ip,
    this.locale,
  });

  /// Platform: android, ios, fuchsia, macos, windows, linux, web.
  final String? platform;

  /// OS version string.
  final String? osVersion;

  /// Device model (e.g. "Pixel 6", "iPhone14,2").
  final String? deviceModel;

  /// Device brand / manufacturer (Android) or "Apple" (iOS).
  final String? deviceBrand;

  /// App display name.
  final String? appName;

  /// App version (e.g. "1.2.0").
  final String? appVersion;

  /// App build number.
  final String? appBuildNumber;

  /// Public IP (from external service).
  final String? ip;

  /// Locale (e.g. "en_US").
  final String? locale;

  static ReportContext? _cached;

  /// Collects device, app, and optional IP context. Cached after first call.
  static Future<ReportContext?> collect({
    bool includeIp = true,
  }) async {
    if (_cached != null) return _cached;

    String? platform;
    String? osVersion;
    String? deviceModel;
    String? deviceBrand;
    String? appName;
    String? appVersion;
    String? appBuildNumber;
    String? ip;
    String? locale;

    try {
      if (kIsWeb) {
        platform = 'web';
      } else {
        platform = _platformName(defaultTargetPlatform);
      }
    } catch (_) {}

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await deviceInfo.androidInfo;
        deviceModel ??= android.model;
        deviceBrand ??= android.manufacturer;
        osVersion ??= android.version.release;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await deviceInfo.iosInfo;
        deviceModel ??= ios.utsname.machine;
        deviceBrand ??= 'Apple';
        osVersion ??= ios.systemVersion;
      }
    } catch (_) {}

    try {
      final info = await PackageInfo.fromPlatform();
      appName = info.appName;
      appVersion = info.version;
      appBuildNumber = info.buildNumber;
    } catch (_) {}

    if (includeIp) {
      try {
        final response = await http
            .get(Uri.parse('https://api.ipify.org'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          ip = response.body.trim();
        }
      } catch (_) {}
    }

    try {
      locale = WidgetsBinding.instance.platformDispatcher.locale.toString();
    } catch (_) {}

    _cached = ReportContext(
      platform: platform,
      osVersion: osVersion,
      deviceModel: deviceModel,
      deviceBrand: deviceBrand,
      appName: appName,
      appVersion: appVersion,
      appBuildNumber: appBuildNumber,
      ip: ip,
      locale: locale,
    );
    return _cached;
  }

  /// Clears cached context (e.g. after re-init).
  static void clearCache() {
    _cached = null;
  }

  bool get isEmpty =>
      platform == null &&
      osVersion == null &&
      deviceModel == null &&
      deviceBrand == null &&
      appName == null &&
      appVersion == null &&
      appBuildNumber == null &&
      ip == null &&
      locale == null;

  /// Map for telegram_templates deviceContext (keys: Platform, OS, Device, Brand, App, Version, Build, IP, Locale).
  Map<String, String?> toMap() => <String, String?>{
        'Platform': platform,
        'OS': osVersion,
        'Device': deviceModel,
        'Brand': deviceBrand,
        'App': appName,
        'Version': appVersion,
        'Build': appBuildNumber,
        'IP': ip,
        'Locale': locale,
      };
}

String _platformName(TargetPlatform p) {
  switch (p) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}
