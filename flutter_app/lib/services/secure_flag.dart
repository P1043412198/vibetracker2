import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Toggles Android `FLAG_SECURE` on the host window so sensitive screens (the
/// password manager) are excluded from screenshots and the recent-apps
/// thumbnail. No-op on non-Android platforms.
class SecureFlag {
  SecureFlag._();

  static const _channel = MethodChannel('ai.vibesight.tracker/secure');

  static Future<void> enable() => _invoke('enable');
  static Future<void> disable() => _invoke('disable');

  static Future<void> _invoke(String method) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Channel not wired (e.g. tests / other host) — ignore.
    }
  }
}
