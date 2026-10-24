import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../data/repositories/settings_repository.dart';

/// Blocked numbers management screen
class BlockedNumbersScreen extends ConsumerStatefulWidget {
  const BlockedNumbersScreen({super.key});

  @override
  ConsumerState<BlockedNumbersScreen> createState() => _BlockedNumbersScreenState();
}

class _BlockedNumbersScreenState extends ConsumerState<BlockedNumbersScreen> {
  final TextEditingController _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _addBlockedNumber() {
    final text = _addController.text.trim();
    if (text.isNotEmpty) {
      ref.read(settingsProvider.notifier).blockNumber(text);
      _addController.clear();
      Navigator.pop(context);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block phone number'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXL)),
        content: TextField(
          controller: _addController,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter phone number'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _addBlockedNumber, child: const Text('Block')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final blocked = settings.blockedNumbers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked numbers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add number',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: blocked.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded, size: 54, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                  const SizedBox(height: 12),
                  const Text('No blocked numbers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              itemCount: blocked.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final number = blocked[index];
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.8),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.block_rounded, color: AppColors.endCallRed),
                    title: Text(number, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: TextButton(
                      onPressed: () => settingsNotifier.unblockNumber(number),
                      child: const Text('Unblock', style: TextStyle(color: AppColors.primaryBlue)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
