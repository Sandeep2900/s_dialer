import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Telephony service managing native call placement, SMS, DTMF tones, and default dialer role
class TelephonyService {
  static const MethodChannel _channel = MethodChannel('com.example.s_dialer/telephony');

  /// Place a phone call directly via native Android ACTION_CALL (fallback to tel: URL)
  Future<bool> makeCall(String number) async {
    final cleanNumber = number.trim();
    if (cleanNumber.isEmpty) return false;

    try {
      final bool? success = await _channel.invokeMethod<bool>('makeCall', {'number': cleanNumber});
      return success ?? false;
    } catch (_) {
      // Fallback via url_launcher for emulator / non-Android environments
      final uri = Uri.parse('tel:${Uri.encodeComponent(cleanNumber)}');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    }
  }

  /// Send an SMS message via native Android SMS intent
  Future<bool> sendSms(String number, [String message = '']) async {
    final cleanNumber = number.trim();
    if (cleanNumber.isEmpty) return false;

    try {
      final bool? success = await _channel.invokeMethod<bool>('sendSms', {
        'number': cleanNumber,
        'message': message,
      });
      return success ?? false;
    } catch (_) {
      final uri = Uri.parse('sms:${Uri.encodeComponent(cleanNumber)}?body=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    }
  }

  /// Play standard DTMF audio tone for keypad digit
  Future<void> playDtmfTone(String digit) async {
    try {
      await _channel.invokeMethod('playTone', {'digit': digit});
    } catch (_) {
      // Silent fail if native audio channel not supported on current platform
    }
  }

  /// Check whether SamDialer is the active system default dialer
  Future<bool> isDefaultDialer() async {
    try {
      final bool? isDefault = await _channel.invokeMethod<bool>('isDefaultDialer');
      return isDefault ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request default dialer role from Android RoleManager
  Future<void> requestDefaultDialerRole() async {
    try {
      await _channel.invokeMethod('requestDefaultDialer');
    } catch (_) {
      // RoleManager fallback handled on Android side
    }
  }

  /// Query detected active SIM cards (Dual-SIM support)
  Future<List<Map<String, String>>> getSimCards() async {
    try {
      final List<dynamic>? rawList = await _channel.invokeMethod<List<dynamic>>('getSimCards');
      if (rawList == null) return [];
      return rawList.map((item) => Map<String, String>.from(item as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Query initial call data if app was cold-started by an incoming or active call intent
  Future<Map<String, dynamic>?> getInitialCall() async {
    try {
      final dynamic res = await _channel.invokeMethod('getInitialCall');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Listen for native requests to show the in-call screen
  void setIncomingCallHandler(void Function(Map<String, dynamic> callData) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'showInCallScreen') {
        if (call.arguments is Map) {
          handler(Map<String, dynamic>.from(call.arguments as Map));
        }
      }
    });
  }
}

final telephonyServiceProvider = Provider<TelephonyService>((ref) {
  return TelephonyService();
});
