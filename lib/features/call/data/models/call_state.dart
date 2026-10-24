class CallState {
  final String number;
  final String? name;
  final String status; // 'idle', 'dialing', 'connecting', 'ringing', 'active', 'holding', 'disconnected'
  final int duration; // in seconds
  final bool isMuted;
  final bool isSpeaker;
  final bool isHold;
  final bool isKeypadVisible;
  final String simInfo;

  const CallState({
    this.number = '',
    this.name,
    this.status = 'idle',
    this.duration = 0,
    this.isMuted = false,
    this.isSpeaker = false,
    this.isHold = false,
    this.isKeypadVisible = false,
    this.simInfo = 'SIM 1 • HD Voice',
  });

  bool get isActiveCall => status != 'idle' && status != 'disconnected';
  bool get isRinging => status == 'ringing';
  bool get isDialing => status == 'dialing' || status == 'connecting';
  bool get isConnected => status == 'active';
  bool get isEnded => status == 'disconnected';

  String get displayTitle {
    if (name != null && name!.trim().isNotEmpty) {
      return name!;
    }
    if (number.trim().isNotEmpty) {
      return number;
    }
    return 'Unknown Caller';
  }

  String get formattedDuration {
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');
    if (duration >= 3600) {
      final hours = (duration ~/ 3600).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String get statusText {
    switch (status) {
      case 'dialing':
        return 'Calling...';
      case 'connecting':
        return 'Connecting...';
      case 'ringing':
        return 'Incoming call...';
      case 'active':
        return formattedDuration;
      case 'holding':
        return 'On hold';
      case 'disconnected':
        return 'Call ended';
      default:
        return '';
    }
  }

  CallState copyWith({
    String? number,
    String? name,
    String? status,
    int? duration,
    bool? isMuted,
    bool? isSpeaker,
    bool? isHold,
    bool? isKeypadVisible,
    String? simInfo,
  }) {
    return CallState(
      number: number ?? this.number,
      name: name ?? this.name,
      status: status ?? this.status,
      duration: duration ?? this.duration,
      isMuted: isMuted ?? this.isMuted,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      isHold: isHold ?? this.isHold,
      isKeypadVisible: isKeypadVisible ?? this.isKeypadVisible,
      simInfo: simInfo ?? this.simInfo,
    );
  }
}
