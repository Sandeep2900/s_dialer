import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/telephony_service.dart';
import '../../../../data/models/call_log_item.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../call/presentation/providers/call_provider.dart';
import '../providers/recents_provider.dart';

/// Call Details Bottom Sheet / Screen displaying call info and actions
class CallDetailScreen extends ConsumerWidget {
  final CallLogItem callLog;

  const CallDetailScreen({super.key, required this.callLog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final telephony = ref.read(telephonyServiceProvider);
    final recentsNotifier = ref.read(recentsProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final formattedDate = DateFormat('EEEE, MMM d, yyyy • h:mm a').format(callLog.timestamp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete from history',
            onPressed: () {
              recentsNotifier.deleteLog(callLog.id);
              context.pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        children: [
          // Centered Avatar & Title
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.getAvatarColor(callLog.name ?? callLog.number),
              child: Icon(callLog.icon, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              callLog.displayTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              callLog.number,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Quick Action Bar (Call, Message, Add to contacts)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionItem(
                  icon: Icons.call_rounded,
                  label: 'Call',
                  color: AppColors.callGreen,
                  onTap: () async {
                    final success = await ref.read(callProvider.notifier).startOutgoingCall(
                      number: callLog.number,
                      name: callLog.name,
                    );
                    if (success && context.mounted) {
                      context.push('/in_call', extra: {'number': callLog.number, 'name': callLog.name});
                    }
                  },
                ),
                _buildActionItem(
                  icon: Icons.message_rounded,
                  label: 'Message',
                  color: AppColors.primaryBlue,
                  onTap: () => telephony.sendSms(callLog.number),
                ),
                _buildActionItem(
                  icon: Icons.person_add_outlined,
                  label: 'Save',
                  color: Colors.orange,
                  onTap: () => context.push('/contacts/edit', extra: callLog.number),
                ),
                _buildActionItem(
                  icon: Icons.block_rounded,
                  label: 'Block',
                  color: AppColors.endCallRed,
                  onTap: () async {
                    await settingsNotifier.blockNumber(callLog.number);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Blocked ${callLog.number}')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Call Record Info Card
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(callLog.icon, color: callLog.iconColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      callLog.type.name.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold, color: callLog.iconColor),
                    ),
                    const Spacer(),
                    Text(callLog.formattedDuration, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                if (callLog.simDisplayName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'SIM: ${callLog.simDisplayName}',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
