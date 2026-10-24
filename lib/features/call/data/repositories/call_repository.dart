import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CallRepository {
  static const MethodChannel _controlChannel = MethodChannel('com.example.s_dialer/call_control');
  static const EventChannel _eventChannel = EventChannel('com.example.s_dialer/call_events');

  Stream<Map<String, dynamic>> get callEventsStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    }).handleError((error) {
      // Return empty map on error to prevent stream crash
      return <String, dynamic>{};
    });
  }

  Future<bool> answer() async {
    try {
      final res = await _controlChannel.invokeMethod<bool>('answer');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hangup() async {
    try {
      final res = await _controlChannel.invokeMethod<bool>('hangup');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setMute(bool muted) async {
    try {
      final res = await _controlChannel.invokeMethod<bool>('mute', {'muted': muted});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setSpeaker(bool on) async {
    try {
      final res = await _controlChannel.invokeMethod<bool>('speaker', {'on': on});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setHold(bool hold) async {
    try {
      final res = await _controlChannel.invokeMethod<bool>('hold', {'hold': hold});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> playDtmf(String digit) async {
    try {
      final res = await _controlChannel.invokeMethod<bool>('playDtmf', {'digit': digit});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopDtmf() async {
    try {
      final res = await _controlChannel.invokeMethod<bool>('stopDtmf');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCallState() async {
    try {
      final res = await _controlChannel.invokeMethod<dynamic>('getCallState');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository();
});
