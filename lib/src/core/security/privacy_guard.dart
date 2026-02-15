import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:no_screenshot/no_screenshot.dart';

/// Cross-platform privacy guard.
///
/// - Android: enables FLAG_SECURE + no_screenshot.
/// - iOS: best-effort no_screenshot only (platform restrictions apply).
/// - Web/Desktop: no-op.
class PrivacyGuard {
  PrivacyGuard._();

  static bool _warnedEnable = false;
  static bool _warnedDisable = false;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _isSupportedPlatform => _isAndroid || _isIOS;

  static Future<void> enable() async {
    if (!_isSupportedPlatform) return;

    try {
      if (_isAndroid) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      }
    } on MissingPluginException {
      _logOnceEnable(
        'Privacy guard: window protection not available on this platform build.',
      );
    } catch (_) {
      _logOnceEnable(
        'Privacy guard: unable to enable window-level protection.',
      );
    }

    try {
      await NoScreenshot.instance.screenshotOff();
    } on MissingPluginException {
      _logOnceEnable(
        'Privacy guard: screenshot blocking plugin not available on this platform build.',
      );
    } catch (_) {
      _logOnceEnable('Privacy guard: unable to enable screenshot blocking.');
    }
  }

  static Future<void> disable() async {
    if (!_isSupportedPlatform) return;

    try {
      if (_isAndroid) {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
    } on MissingPluginException {
      _logOnceDisable(
        'Privacy guard: window protection clear not available on this platform build.',
      );
    } catch (_) {
      _logOnceDisable(
        'Privacy guard: unable to clear window-level protection.',
      );
    }

    try {
      await NoScreenshot.instance.screenshotOn();
    } on MissingPluginException {
      _logOnceDisable(
        'Privacy guard: screenshot unblock plugin not available on this platform build.',
      );
    } catch (_) {
      _logOnceDisable('Privacy guard: unable to disable screenshot blocking.');
    }
  }

  static void _logOnceEnable(String message) {
    if (_warnedEnable) return;
    _warnedEnable = true;
    debugPrint(message);
  }

  static void _logOnceDisable(String message) {
    if (_warnedDisable) return;
    _warnedDisable = true;
    debugPrint(message);
  }
}
