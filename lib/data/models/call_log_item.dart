import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum CallType { incoming, outgoing, missed, rejected, blocked }

/// Call history entry matching Samsung Recents design
class CallLogItem {
  final String id;
  final String number;
  final String? name;
  final CallType type;
  final DateTime timestamp;
  final int durationSeconds;
  final String? simDisplayName;
  final int count; // consecutive calls grouped

  const CallLogItem({
    required this.id,
    required this.number,
    this.name,
    required this.type,
    required this.timestamp,
    this.durationSeconds = 0,
    this.simDisplayName,
    this.count = 1,
  });

  /// Label shown in UI ("Mom (3)" or "(555) 123-4567")
  String get displayTitle {
    final title = (name != null && name!.trim().isNotEmpty)
        ? name!
        : (number.trim().isNotEmpty ? number : 'Unknown');
    return count > 1 ? '$title ($count)' : title;
  }

  /// Icon corresponding to Samsung call type
  IconData get icon {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received_rounded;
      case CallType.outgoing:
        return Icons.call_made_rounded;
      case CallType.missed:
        return Icons.call_missed_rounded;
      case CallType.rejected:
        return Icons.call_end_rounded;
      case CallType.blocked:
        return Icons.block_rounded;
    }
  }

  /// Color corresponding to Samsung call type
  Color get iconColor {
    switch (type) {
      case CallType.missed:
        return AppColors.missedCall;
      case CallType.rejected:
      case CallType.blocked:
        return AppColors.endCallRed;
      case CallType.incoming:
      case CallType.outgoing:
        return AppColors.callGreen;
    }
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '0s';
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    if (mins == 0) return '${secs}s';
    return '${mins}m ${secs}s';
  }

  CallLogItem copyWith({
    String? id,
    String? number,
    String? name,
    CallType? type,
    DateTime? timestamp,
    int? durationSeconds,
    String? simDisplayName,
    int? count,
  }) {
    return CallLogItem(
      id: id ?? this.id,
      number: number ?? this.number,
      name: name ?? this.name,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      simDisplayName: simDisplayName ?? this.simDisplayName,
      count: count ?? this.count,
    );
  }
}
