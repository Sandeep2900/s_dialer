import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/permissions/permission_provider.dart';

/// Contextual permission rationale screen matching Samsung One UI design
class PermissionRationaleScreen extends ConsumerWidget {
  const PermissionRationaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final notifier = ref.read(permissionsProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.paddingL),
              // App Logo / Icon Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: AppColors.primaryBlue,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),
              Text(
                'SamDialer needs your permission',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              Text(
                'To place calls, manage contacts, and display your call history, SamDialer requires access to device features.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingXL),
              // Permission items
              Expanded(
                child: ListView(
                  children: [
                    _buildPermissionItem(
                      icon: Icons.phone_rounded,
                      iconColor: AppColors.callGreen,
                      title: 'Phone & Calling',
                      description:
                          'Allows the app to place calls and detect phone states.',
                      isGranted: permissions.isPhoneGranted,
                      isDark: isDark,
                    ),
                    _buildPermissionItem(
                      icon: Icons.contacts_rounded,
                      iconColor: AppColors.primaryBlue,
                      title: 'Contacts',
                      description:
                          'Access device contacts to search, display, and manage your address book.',
                      isGranted: permissions.isContactsGranted,
                      isDark: isDark,
                    ),
                    _buildPermissionItem(
                      icon: Icons.history_rounded,
                      iconColor: Colors.orange,
                      title: 'Call History',
                      description:
                          'Displays recent incoming, outgoing, and missed call records.',
                      isGranted: permissions.isCallLogGranted,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              // Action Buttons
              if (permissions.isPermanentlyDenied)
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
                  decoration: BoxDecoration(
                    color: AppColors.endCallRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    border: Border.all(
                      color: AppColors.endCallRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.endCallRed,
                        size: 20,
                      ),
                      const SizedBox(width: AppDimensions.paddingS),
                      Expanded(
                        child: Text(
                          'Some permissions were declined permanently. Please enable them in app settings.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppDimensions.pillBorderRadius,
                    ),
                  ),
                  onPressed: () async {
                    if (permissions.isPermanentlyDenied) {
                      await notifier.openSettings();
                    } else {
                      final granted = await notifier.requestCore();
                      if (granted && context.mounted) {
                        context.pop();
                      }
                    }
                  },
                  child: Text(
                    permissions.isPermanentlyDenied
                        ? 'Open Settings'
                        : 'Continue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    'Not now',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isGranted,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isGranted)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.callGreen,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
