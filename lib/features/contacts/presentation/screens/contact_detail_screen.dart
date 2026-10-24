import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/telephony_service.dart';
import '../../../../data/models/contact_item.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../call/presentation/providers/call_provider.dart';
import '../providers/contacts_provider.dart';

/// Samsung One UI Contact Detail Screen with quick actions & full details
class ContactDetailScreen extends ConsumerWidget {
  final ContactItem contact;

  const ContactDetailScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final telephony = ref.read(telephonyServiceProvider);
    final contactsNotifier = ref.read(contactsProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              contact.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: contact.isFavorite ? Colors.amber : null,
            ),
            tooltip: 'Favorite',
            onPressed: () => contactsNotifier.toggleFavorite(contact.id),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push('/contacts/edit', extra: contact),
          ),
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusM)),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'block', child: Text('Block contact')),
              const PopupMenuItem(value: 'delete', child: Text('Delete contact')),
            ],
            onSelected: (val) async {
              if (val == 'block') {
                await settingsNotifier.blockNumber(contact.primaryNumber);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Blocked ${contact.displayName}')),
                  );
                }
              } else if (val == 'delete') {
                await contactsNotifier.deleteContact(contact.id);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
        children: [
          const SizedBox(height: 16),
          // Large Centered Avatar Header
          Center(
            child: CircleAvatar(
              radius: AppDimensions.avatarLargeSize / 2,
              backgroundColor: contact.avatarColor,
              child: Text(
                contact.initials,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              contact.displayName,
              style: theme.textTheme.displayMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          if (contact.company != null && contact.company!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                contact.company!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Quick Action Row (Call, Message, Video, Email) - Samsung Style
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
                _buildQuickAction(
                  icon: Icons.call_rounded,
                  label: 'Call',
                  color: AppColors.callGreen,
                  onTap: () async {
                    final success = await ref.read(callProvider.notifier).startOutgoingCall(
                      number: contact.primaryNumber,
                      name: contact.displayName,
                    );
                    if (success && context.mounted) {
                      context.push('/in_call', extra: {
                        'number': contact.primaryNumber,
                        'name': contact.displayName,
                      });
                    }
                  },
                ),
                _buildQuickAction(
                  icon: Icons.message_rounded,
                  label: 'Text',
                  color: AppColors.primaryBlue,
                  onTap: () => telephony.sendSms(contact.primaryNumber),
                ),
                _buildQuickAction(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: Colors.purple,
                  onTap: () => telephony.makeCall(contact.primaryNumber),
                ),
                _buildQuickAction(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  color: Colors.orange,
                  onTap: () {
                    if (contact.emails.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Emailing ${contact.emails.first.address}')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Phone Numbers Section
          if (contact.phones.isNotEmpty) ...[
            _buildSectionHeader('Phone numbers'),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.8),
              ),
              child: Column(
                children: contact.phones.map((phone) {
                  return ListTile(
                    title: Text(phone.number, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(phone.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.call_rounded, color: AppColors.callGreen),
                          onPressed: () async {
                            final success = await ref.read(callProvider.notifier).startOutgoingCall(
                              number: phone.number,
                              name: contact.displayName,
                            );
                            if (success && context.mounted) {
                              context.push('/in_call', extra: {
                                'number': phone.number,
                                'name': contact.displayName,
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.message_rounded, color: AppColors.primaryBlue),
                          onPressed: () => telephony.sendSms(phone.number),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Emails Section
          if (contact.emails.isNotEmpty) ...[
            _buildSectionHeader('Email'),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.8),
              ),
              child: Column(
                children: contact.emails.map((email) {
                  return ListTile(
                    title: Text(email.address),
                    subtitle: Text(email.label),
                    trailing: const Icon(Icons.email_outlined),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Notes Section
          if (contact.notes != null && contact.notes!.isNotEmpty) ...[
            _buildSectionHeader('Notes'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.8),
              ),
              child: Text(contact.notes!),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
      ),
    );
  }
}
