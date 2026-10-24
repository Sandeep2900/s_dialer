import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/permissions/permission_provider.dart';
import '../../../../core/services/telephony_service.dart';
import '../../../../core/services/vcf_service.dart';
import '../../../../data/repositories/contacts_repository.dart';
import '../../../../data/repositories/google_sync_repository.dart';
import '../../../../data/repositories/settings_repository.dart';

/// Theme Mode Riverpod Provider - default to Samsung One UI Dark Mode
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// Comprehensive Samsung One UI Settings Screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDefaultDialer = false;

  @override
  void initState() {
    super.initState();
    _checkDefaultDialer();
  }

  Future<void> _checkDefaultDialer() async {
    final isDefault = await ref.read(telephonyServiceProvider).isDefaultDialer();
    if (mounted) setState(() => _isDefaultDialer = isDefault);
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final googleSync = ref.watch(googleSyncProvider);
    final googleSyncNotifier = ref.read(googleSyncProvider.notifier);
    final telephony = ref.read(telephonyServiceProvider);
    final contactsRepo = ref.read(contactsRepositoryProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
        children: [
          // Section: Default Phone App (Milestone 7)
          _buildSectionHeader('Default Phone App', isDark),
          _buildCard(
            isDark: isDark,
            children: [
              ListTile(
                title: const Text('Set as default phone app'),
                subtitle: Text(
                  _isDefaultDialer
                      ? 'SamDialer is your default phone app'
                      : 'Required for in-call screen & call management',
                ),
                trailing: _isDefaultDialer
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.callGreen)
                    : FilledButton.tonal(
                        onPressed: () async {
                          await telephony.requestDefaultDialerRole();
                          await _checkDefaultDialer();
                        },
                        child: const Text('Set default'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Section: Keypad & Sound
          _buildSectionHeader('Keypad & Tones', isDark),
          _buildCard(
            isDark: isDark,
            children: [
              SwitchListTile(
                title: const Text('Dial pad tones (DTMF)'),
                subtitle: const Text('Play sound when keypad keys are pressed'),
                value: settings.dtmfSoundEnabled,
                onChanged: settingsNotifier.toggleDtmf,
              ),
              Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              SwitchListTile(
                title: const Text('Dial pad vibration'),
                subtitle: const Text('Vibrate when tapping dial pad numbers'),
                value: settings.hapticsEnabled,
                onChanged: settingsNotifier.toggleHaptics,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Section: Google Account & Sync (Milestone 6)
          _buildSectionHeader('Accounts & Sync', isDark),
          _buildCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined, color: AppColors.primaryBlue),
                title: Text(googleSync.isSignedIn ? (googleSync.displayName ?? 'Google Account') : 'Google Account'),
                subtitle: Text(googleSync.isSignedIn ? (googleSync.accountEmail ?? '') : 'Sign in to sync Google contacts'),
                trailing: googleSync.isSignedIn
                    ? TextButton(
                        onPressed: googleSyncNotifier.signOut,
                        child: const Text('Sign out'),
                      )
                    : FilledButton.tonal(
                        onPressed: googleSyncNotifier.signIn,
                        child: const Text('Sign in'),
                      ),
              ),
              if (googleSync.isSignedIn) ...[
                Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                ListTile(
                  title: const Text('Sync now'),
                  subtitle: Text(
                    googleSync.lastSyncTime != null
                        ? 'Last synced: ${googleSync.lastSyncTime}'
                        : 'Tap to synchronize contacts',
                  ),
                  trailing: googleSync.isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.sync_rounded),
                          onPressed: googleSyncNotifier.syncNow,
                        ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Section: Contacts Display & Backup
          _buildSectionHeader('Contacts', isDark),
          _buildCard(
            isDark: isDark,
            children: [
              SwitchListTile(
                title: const Text('Sort by last name'),
                subtitle: const Text('Organize contacts alphabetically by last name'),
                value: settings.sortByLastName,
                onChanged: settingsNotifier.toggleSortByLastName,
              ),
              Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              ListTile(
                title: const Text('Blocked numbers'),
                subtitle: Text('${settings.blockedNumbers.length} numbers blocked'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/settings/blocked'),
              ),
              Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              ListTile(
                title: const Text('Export contacts (.vcf)'),
                subtitle: const Text('Save contacts as vCard file'),
                trailing: const Icon(Icons.upload_file_rounded),
                onTap: () {
                  final vcf = VcfService.exportToVcf(contactsRepo.cachedContacts);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exported ${contactsRepo.cachedContacts.length} contacts to vCard format (${vcf.length} bytes)')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Section: Appearance
          _buildSectionHeader('Appearance', isDark),
          _buildCard(
            isDark: isDark,
            children: [
              ListTile(
                title: const Text('Theme'),
                subtitle: Text(_getThemeModeName(themeMode)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showThemeDialog(context, ref, themeMode),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Section: Permissions
          _buildSectionHeader('Permissions & Access', isDark),
          _buildCard(
            isDark: isDark,
            children: [
              ListTile(
                title: const Text('App Permissions'),
                subtitle: Text(
                  permissions.hasAllCorePermissions
                      ? 'All core permissions granted'
                      : 'Missing some required permissions',
                ),
                trailing: Icon(
                  permissions.hasAllCorePermissions ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: permissions.hasAllCorePermissions ? AppColors.callGreen : Colors.orange,
                ),
                onTap: () => context.push('/permissions'),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Section: About
          _buildSectionHeader('About', isDark),
          _buildCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.callGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.phone_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                ),
                title: const Text('SamDialer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Faithful Samsung One UI Phone Experience\nVersion 1.0.0 • Production Quality'),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingXS),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryBlue, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.8),
      ),
      child: Column(children: children),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Match system settings';
      case ThemeMode.light:
        return 'Light theme';
      case ThemeMode.dark:
        return 'Dark theme (AMOLED Black)';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose theme'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXL)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOptionTile(context: context, ref: ref, label: 'System default', mode: ThemeMode.system, isSelected: current == ThemeMode.system),
            _buildThemeOptionTile(context: context, ref: ref, label: 'Light', mode: ThemeMode.light, isSelected: current == ThemeMode.light),
            _buildThemeOptionTile(context: context, ref: ref, label: 'Dark (One UI Black)', mode: ThemeMode.dark, isSelected: current == ThemeMode.dark),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOptionTile({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required ThemeMode mode,
    required bool isSelected,
  }) {
    return ListTile(
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusM)),
      onTap: () {
        ref.read(themeModeProvider.notifier).state = mode;
        Navigator.pop(context);
      },
    );
  }
}
