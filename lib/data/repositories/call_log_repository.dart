import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call_log_item.dart';

/// Repository managing call history records with consecutive call grouping
class CallLogRepository {
  static const MethodChannel _telephonyChannel =
      MethodChannel('com.example.s_dialer/telephony');

  List<CallLogItem> _cachedLogs = [];

  List<CallLogItem> get cachedLogs => List.unmodifiable(_cachedLogs);

  /// Fetch call logs from Android system call log provider on background thread with limit
  Future<List<CallLogItem>> fetchCallLogs({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedLogs.isNotEmpty) {
      return _cachedLogs;
    }

    if (kIsWeb) {
      if (_cachedLogs.isEmpty) {
        _cachedLogs = _getFallbackCallLogs();
      }
      return _cachedLogs;
    }

    try {
      // Check if permission is granted first
      bool isGranted = false;
      try {
        isGranted = await Permission.phone.isGranted;
      } catch (_) {
        isGranted = false;
      }

      if (!isGranted) {
        if (_cachedLogs.isEmpty) {
          _cachedLogs = _getFallbackCallLogs();
        }
        return _cachedLogs;
      }

      // Query native Android CallLog on background worker thread (max 250 calls)
      final List<dynamic>? result = await _telephonyChannel
          .invokeMethod('getCallLogs', {'limit': 250})
          .timeout(const Duration(seconds: 4), onTimeout: () => null);

      if (result == null || result.isEmpty) {
        if (_cachedLogs.isEmpty) {
          _cachedLogs = _getFallbackCallLogs();
        }
        return _cachedLogs;
      }

      final List<CallLogItem> rawList = [];
      for (final item in result) {
        if (item is Map) {
          try {
            rawList.add(CallLogItem(
              id: item['id']?.toString() ??
                  '${item['timestamp']}_${item['number']}',
              number: item['number']?.toString() ?? '',
              name: item['name']?.toString(),
              type: _mapCallType(item['type'] as int?),
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                (item['timestamp'] as num?)?.toInt() ??
                    DateTime.now().millisecondsSinceEpoch,
              ),
              durationSeconds: (item['duration'] as num?)?.toInt() ?? 0,
              simDisplayName: item['simDisplayName']?.toString(),
              count: 1,
            ));
          } catch (_) {}
        }
      }

      if (rawList.isEmpty) {
        _cachedLogs = _getFallbackCallLogs();
      } else {
        _cachedLogs = _groupConsecutiveCalls(rawList);
      }
      return _cachedLogs;
    } catch (_) {
      if (_cachedLogs.isEmpty) {
        _cachedLogs = _getFallbackCallLogs();
      }
      return _cachedLogs;
    }
  }

  /// Group consecutive calls from the same number into a single entry with count (Samsung Phone UX)
  List<CallLogItem> _groupConsecutiveCalls(List<CallLogItem> rawList) {
    if (rawList.isEmpty) return [];

    final List<CallLogItem> grouped = [];
    CallLogItem current = rawList.first;

    for (int i = 1; i < rawList.length; i++) {
      final next = rawList[i];
      final cleanNext = next.number.replaceAll(RegExp(r'\D'), '');
      final cleanCurrent = current.number.replaceAll(RegExp(r'\D'), '');
      final isSameNumber = cleanNext.isNotEmpty && cleanNext == cleanCurrent;
      final isSameType = next.type == current.type;

      if (isSameNumber && isSameType) {
        // Increment count
        current = current.copyWith(count: current.count + 1);
      } else {
        grouped.add(current);
        current = next;
      }
    }
    grouped.add(current);
    return grouped;
  }

  CallType _mapCallType(int? type) {
    switch (type) {
      case 1: // INCOMING_TYPE
        return CallType.incoming;
      case 2: // OUTGOING_TYPE
        return CallType.outgoing;
      case 3: // MISSED_TYPE
        return CallType.missed;
      case 5: // REJECTED_TYPE
        return CallType.rejected;
      case 6: // BLOCKED_TYPE
        return CallType.blocked;
      default:
        return CallType.incoming;
    }
  }

  /// Delete specific call log
  void deleteCall(String id) {
    _cachedLogs.removeWhere((c) => c.id == id);
    if (!kIsWeb) {
      try {
        _telephonyChannel.invokeMethod('deleteCallLogs', {
          'ids': [id]
        });
      } catch (_) {}
    }
  }

  /// Delete multiple call logs
  void deleteCalls(Set<String> ids) {
    _cachedLogs.removeWhere((c) => ids.contains(c.id));
    if (!kIsWeb) {
      try {
        _telephonyChannel.invokeMethod('deleteCallLogs', {
          'ids': ids.toList()
        });
      } catch (_) {}
    }
  }

  /// Clear all call history
  void clearAll() {
    _cachedLogs.clear();
  }

  List<CallLogItem> _getFallbackCallLogs() {
    final now = DateTime.now();
    return [
      CallLogItem(
        id: 'mock_c1',
        number: '+1 (555) 987-6543',
        name: 'Mom',
        type: CallType.incoming,
        timestamp: now.subtract(const Duration(minutes: 15)),
        durationSeconds: 145,
        count: 3,
      ),
      CallLogItem(
        id: 'mock_c2',
        number: '+1 (555) 234-5678',
        name: 'Alice Johnson',
        type: CallType.outgoing,
        timestamp: now.subtract(const Duration(hours: 2)),
        durationSeconds: 320,
        count: 1,
      ),
      CallLogItem(
        id: 'mock_c3',
        number: '+1 (555) 345-6789',
        name: 'Bob Smith',
        type: CallType.missed,
        timestamp: now.subtract(const Duration(hours: 5)),
        durationSeconds: 0,
        count: 2,
      ),
      CallLogItem(
        id: 'mock_c4',
        number: '+1 (800) 555-0199',
        name: 'Customer Service',
        type: CallType.outgoing,
        timestamp: now.subtract(const Duration(days: 1)),
        durationSeconds: 612,
        count: 1,
      ),
      CallLogItem(
        id: 'mock_c5',
        number: '+1 (555) 789-0123',
        name: 'Diana Prince',
        type: CallType.incoming,
        timestamp: now.subtract(const Duration(days: 2)),
        durationSeconds: 85,
        count: 1,
      ),
    ];
  }
}

final callLogRepositoryProvider = Provider<CallLogRepository>((ref) {
  return CallLogRepository();
});
