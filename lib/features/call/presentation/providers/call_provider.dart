import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/call_state.dart';
import '../../data/repositories/call_repository.dart';
import '../../../../core/services/telephony_service.dart';

class CallNotifier extends StateNotifier<CallState> {
  final Ref _ref;
  StreamSubscription? _eventSubscription;
  Timer? _durationTimer;

  CallNotifier(this._ref) : super(const CallState()) {
    _init();
  }

  void _init() {
    final repo = _ref.read(callRepositoryProvider);
    _eventSubscription = repo.callEventsStream.listen((event) {
      if (event.isNotEmpty) {
        _handleCallEvent(event);
      }
    });

    // Check if there is an ongoing call on startup
    repo.getCallState().then((stateMap) {
      if (stateMap != null && stateMap.isNotEmpty) {
        _handleCallEvent(stateMap);
      }
    });
  }

  void _handleCallEvent(Map<String, dynamic> event) {
    final rawState = (event['state'] as String? ?? 'unknown').toLowerCase();
    final number = event['number'] as String? ?? state.number;
    final name = event['name'] as String? ?? state.name;
    final duration = event['duration'] as int? ?? 0;

    debugPrint('Native Call Event: state=$rawState, number=$number, name=$name');

    if (rawState == 'disconnected' || rawState == 'disconnecting') {
      _durationTimer?.cancel();
      state = state.copyWith(
        status: 'disconnected',
      );
      // Reset to idle after 600ms
      Future.delayed(const Duration(milliseconds: 600), () {
        if (state.status == 'disconnected') {
          state = const CallState();
        }
      });
      return;
    }

    String mappedStatus = state.status;
    if (rawState == 'dialing' || rawState == 'connecting') {
      mappedStatus = 'dialing';
    } else if (rawState == 'ringing') {
      mappedStatus = 'ringing';
    } else if (rawState == 'holding') {
      mappedStatus = 'holding';
    } else if (rawState == 'active') {
      mappedStatus = 'active';
      _startDurationTimer(duration);
    } else if (rawState == 'idle') {
      _durationTimer?.cancel();
      state = const CallState();
      return;
    }

    state = state.copyWith(
      number: number.isNotEmpty ? number : state.number,
      name: name ?? state.name,
      status: mappedStatus,
      duration: duration > 0 ? duration : state.duration,
    );
  }

  void _startDurationTimer([int initialSeconds = 0]) {
    _durationTimer?.cancel();
    if (initialSeconds > 0) {
      state = state.copyWith(duration: initialSeconds);
    }
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == 'active') {
        state = state.copyWith(duration: state.duration + 1);
      }
    });
  }

  /// Manually initiate an outgoing call and set up state
  Future<bool> startOutgoingCall({required String number, String? name}) async {
    final cleanNumber = number.trim();
    if (cleanNumber.isEmpty) return false;

    _durationTimer?.cancel();
    state = CallState(
      number: cleanNumber,
      name: name,
      status: 'dialing',
      duration: 0,
      isMuted: false,
      isSpeaker: false,
      isHold: false,
      isKeypadVisible: false,
    );

    // Call native placeCall
    final success = await _ref.read(telephonyServiceProvider).makeCall(cleanNumber);
    if (!success) {
      state = state.copyWith(status: 'disconnected');
      Future.delayed(const Duration(milliseconds: 600), () {
        state = const CallState();
      });
      return false;
    }

    return true;
  }

  Future<void> answer() async {
    await _ref.read(callRepositoryProvider).answer();
    state = state.copyWith(status: 'active');
    _startDurationTimer(0);
  }

  Future<void> hangup() async {
    _durationTimer?.cancel();
    state = state.copyWith(status: 'disconnected');
    try {
      await _ref.read(callRepositoryProvider).hangup();
    } catch (e) {
      debugPrint('Error hanging up: $e');
    }
    Future.delayed(const Duration(milliseconds: 600), () {
      if (state.status == 'disconnected') {
        state = const CallState();
      }
    });
  }

  Future<void> toggleMute() async {
    final newMute = !state.isMuted;
    await _ref.read(callRepositoryProvider).setMute(newMute);
    state = state.copyWith(isMuted: newMute);
  }

  Future<void> toggleSpeaker() async {
    final newSpeaker = !state.isSpeaker;
    await _ref.read(callRepositoryProvider).setSpeaker(newSpeaker);
    state = state.copyWith(isSpeaker: newSpeaker);
  }

  Future<void> toggleHold() async {
    final newHold = !state.isHold;
    await _ref.read(callRepositoryProvider).setHold(newHold);
    state = state.copyWith(
      isHold: newHold,
      status: newHold ? 'holding' : 'active',
    );
  }

  void toggleKeypad() {
    state = state.copyWith(isKeypadVisible: !state.isKeypadVisible);
  }

  Future<void> sendDtmf(String digit) async {
    if (digit.isEmpty) return;
    await _ref.read(callRepositoryProvider).playDtmf(digit);
    _ref.read(telephonyServiceProvider).playDtmfTone(digit);
    await Future.delayed(const Duration(milliseconds: 150));
    await _ref.read(callRepositoryProvider).stopDtmf();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }
}

final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  return CallNotifier(ref);
});
