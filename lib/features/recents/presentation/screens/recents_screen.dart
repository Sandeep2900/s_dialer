import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/telephony_service.dart';
import '../../../../core/widgets/one_ui_header.dart';
import '../../../../core/widgets/permission_banner.dart';
import '../../../../core/widgets/pill_search_bar.dart';
import '../../../../core/widgets/swipe_to_call_tile.dart';
import '../../../../data/models/call_log_item.dart';
import '../../../call/presentation/providers/call_provider.dart';
import '../providers/recents_provider.dart';

/// Samsung One UI Recents Tab Screen with swipe-to-call & multi-select delete
class RecentsScreen extends ConsumerStatefulWidget {
  const RecentsScreen({super.key});

  @override
  ConsumerState<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends ConsumerState<RecentsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final logDate = DateTime(date.year, date.month, date.day);

    if (logDate == today) return 'Today';
    if (logDate == yesterday) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final recentsState = ref.watch(recentsProvider);
    final recentsNotifier = ref.read(recentsProvider.notifier);
    final telephony = ref.read(telephonyServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isMulti = recentsState.isMultiSelectMode;

    return PopScope(
      canPop: !isMulti,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isMulti) {
          recentsNotifier.exitMultiSelect();
        }
      },
      child: Scaffold(
        appBar: isMulti
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: recentsNotifier.exitMultiSelect,
                ),
              title: Text('${recentsState.selectedIds.length} selected'),
              actions: [
                TextButton(
                  onPressed: recentsNotifier.selectAll,
                  child: const Text('Select all'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.endCallRed),
                  tooltip: 'Delete',
                  onPressed: recentsNotifier.deleteSelected,
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => recentsNotifier.loadLogs(forceRefresh: true),
        color: AppColors.primaryBlue,
        child: CustomScrollView(
          slivers: [
            if (!isMulti)
              OneUiHeader(
                title: 'Recents',
                subtitle: recentsState.filterIndex == 0 ? 'All calls' : 'Missed calls',
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (!isMulti) ...[
                    PillSearchBar(
                      controller: _searchController,
                      hintText: 'Search call history',
                      onChanged: (query) => recentsNotifier.search(query),
                    ),
                    const PermissionBanner(
                      title: 'Call history permission required',
                      message: 'Grant access to view your recent incoming and outgoing calls.',
                    ),
                    // Filter Chips (All / Missed)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingM,
                        vertical: AppDimensions.paddingXS,
                      ),
                      child: Row(
                        children: [
                          _buildFilterChip(0, 'All', recentsState.filterIndex, isDark, recentsNotifier),
                          const SizedBox(width: AppDimensions.paddingS),
                          _buildFilterChip(1, 'Missed', recentsState.filterIndex, isDark, recentsNotifier),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                  ],
                ],
              ),
            ),
            // Call Log List grouped into cards
            if (recentsState.filteredLogs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingXXL),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.history_rounded, size: 36, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text('No recent calls', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: recentsState.filteredLogs.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        indent: 64,
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      ),
                      itemBuilder: (context, index) {
                        final log = recentsState.filteredLogs[index];
                        final isSelected = recentsState.selectedIds.contains(log.id);

                        return SwipeToCallTile(
                          enabled: !isMulti,
                          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                          onSwipeRight: () async {
                            final success = await ref.read(callProvider.notifier).startOutgoingCall(
                              number: log.number,
                              name: log.name,
                            );
                            if (success && context.mounted) {
                              context.push('/in_call', extra: {
                                'number': log.number,
                                'name': log.name,
                              });
                            }
                          },
                          onSwipeLeft: () => telephony.sendSms(log.number),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            leading: isMulti
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => recentsNotifier.toggleSelect(log.id),
                                    shape: const CircleBorder(),
                                    activeColor: AppColors.primaryBlue,
                                  )
                                : CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                    child: Icon(log.icon, color: log.iconColor, size: 20),
                                  ),
                            title: Text(
                              log.displayTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: log.type == CallType.missed
                                    ? AppColors.missedCall
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  _formatDateHeader(log.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                if (log.simDisplayName != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${log.simDisplayName}',
                                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.info_outline_rounded, size: 22),
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              onPressed: () => context.push('/recents/detail', extra: log),
                            ),
                            onTap: () {
                              if (isMulti) {
                                recentsNotifier.toggleSelect(log.id);
                              } else {
                                context.push('/recents/detail', extra: log);
                              }
                            },
                            onLongPress: () {
                              if (!isMulti) {
                                recentsNotifier.enterMultiSelect(log.id);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 125)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildFilterChip(
    int index,
    String label,
    int selectedIndex,
    bool isDark,
    RecentsNotifier notifier,
  ) {
    final isSelected = selectedIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) notifier.setFilter(index);
      },
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected
            ? Colors.white
            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      ),
      selectedColor: AppColors.primaryBlue,
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: AppDimensions.pillBorderRadius,
        side: BorderSide.none,
      ),
    );
  }
}
