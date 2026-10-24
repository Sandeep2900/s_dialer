import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/telephony_service.dart';
import '../../../../core/widgets/permission_banner.dart';
import '../providers/keypad_provider.dart';

/// Samsung One UI Keypad Tab Screen with T9 live suggestions & native calling
class KeypadScreen extends ConsumerStatefulWidget {
  const KeypadScreen({super.key});

  @override
  ConsumerState<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends ConsumerState<KeypadScreen> {
  // Cache key size so keyboard open/close (viewInsets change) doesn't rebuild.
  double _dynamicKeySize = 56.0;
  bool _isCompact = false;
  Size _lastSize = Size.zero;
  bool _isDefaultDialer = true;
  bool _dismissedDefaultBanner = false;

  @override
  void initState() {
    super.initState();
    _checkDefaultDialer();
  }

  Future<void> _checkDefaultDialer() async {
    final isDefault = await ref.read(telephonyServiceProvider).isDefaultDialer();
    if (mounted) {
      setState(() => _isDefaultDialer = isDefault);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only recompute when screen SIZE changes (not when keyboard opens).
    // MediaQuery.sizeOf does NOT rebuild on viewInsets/keyboard changes.
    final size = MediaQuery.sizeOf(context);
    if (size != _lastSize) {
      _lastSize = size;
      final padding = MediaQuery.paddingOf(context);
      final estimatedKeypadHeight = (size.height
              - padding.top
              - padding.bottom
              - 56   // app bar
              - 140  // number display area
              - 90)  // bottom nav bar
          .clamp(160.0, 420.0);
      _dynamicKeySize = ((estimatedKeypadHeight - 32) / 5.2).clamp(42.0, 68.0);
      _isCompact = _dynamicKeySize < 56;
    }
  }

  @override
  Widget build(BuildContext context) {
    final keypadState = ref.watch(keypadProvider);
    final keypadNotifier = ref.read(keypadProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: null,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 26),
            tooltip: 'Search',
            onPressed: () => context.push('/contacts'),
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'speed_dial',
                    child: Text('Speed dial numbers'),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('Settings'),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'settings') {
                    context.push('/settings');
                  }
                },
              ),
              // Samsung One UI signature orange notification dot
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6D00),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppDimensions.paddingS),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const PermissionBanner(
              title: 'Permissions needed for calling',
              message: 'Allow Phone permissions to dial numbers and place calls.',
            ),
            // Default Phone App Banner (Required for native in-call screen)
            if (!_isDefaultDialer && !_dismissedDefaultBanner)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F2E) : const Color(0xFFEBF3FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_forwarded_rounded, color: AppColors.primaryBlue, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Set as default phone app',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Required for custom in-call screen',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await ref.read(telephonyServiceProvider).requestDefaultDialerRole();
                        await _checkDefaultDialer();
                      },
                      child: const Text('Set Default', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white54 : Colors.black45),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() => _dismissedDefaultBanner = true);
                      },
                    ),
                  ],
                ),
              ),
            // Live T9 Contact Suggestions Strip
            if (keypadState.suggestions.isNotEmpty)
              Container(
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: keypadState.suggestions.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final suggestion = keypadState.suggestions[index];
                    return ActionChip(
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundColor: suggestion.avatarColor,
                        child: Text(
                          suggestion.initials,
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      label: Text('${suggestion.displayName} (${suggestion.primaryNumber})'),
                      onPressed: () => keypadNotifier.setNumber(suggestion.primaryNumber),
                    );
                  },
                ),
              ),
            // Formatted Number Display Area
            Expanded(
              flex: 2,
              child: GestureDetector(
                onLongPress: () async {
                  final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                  if (clipboardData != null && clipboardData.text != null) {
                    keypadNotifier.setNumber(clipboardData.text!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pasted from clipboard'), duration: Duration(seconds: 1)),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: 2),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          keypadState.formattedNumber.isEmpty ? '' : keypadState.formattedNumber,
                          key: const Key('keypad_number_display'),
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w400,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      if (keypadState.rawNumber.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    context.push('/contacts/edit', extra: keypadState.rawNumber);
                                  },
                                  icon: const Icon(Icons.person_add_outlined, size: 16),
                                  label: const Text('Add to contacts', style: TextStyle(fontSize: 13)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryBlue,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    ref.read(telephonyServiceProvider).sendSms(keypadState.rawNumber);
                                  },
                                  icon: const Icon(Icons.message_outlined, size: 16),
                                  label: const Text('Send SMS', style: TextStyle(fontSize: 13)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryBlue,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Keypad grid — uses cached _dynamicKeySize from didChangeDependencies.
            // This avoids rebuilding when keyboard opens (viewInsets change).
            Expanded(
              flex: 6,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isCompact ? AppDimensions.paddingL : AppDimensions.paddingXL,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _lastSize.width > 100 ? (_lastSize.width - (_isCompact ? 32 : 48)) : 320.0,
                    height: (_dynamicKeySize * 5.2 + 32).clamp(160.0, 420.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKeypadRow(['1', '2', '3'], ['', 'ABC', 'DEF'], _dynamicKeySize, isDark, keypadNotifier),
                        _buildKeypadRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO'], _dynamicKeySize, isDark, keypadNotifier),
                        _buildKeypadRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ'], _dynamicKeySize, isDark, keypadNotifier),
                        _buildKeypadRow(['*', '0', '#'], ['', '+', ''], _dynamicKeySize, isDark, keypadNotifier),
                        // Call & Backspace Action Row
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Expanded(child: SizedBox()),
                              // Green Call Button
                              GestureDetector(
                                key: const Key('keypad_call_button'),
                                onTap: () async {
                                  if (keypadState.rawNumber.isEmpty) return;
                                  final num = keypadState.rawNumber;
                                  final name = keypadState.suggestions.isNotEmpty ? keypadState.suggestions.first.displayName : null;
                                  final success = await keypadNotifier.makeCall();
                                  if (success && context.mounted) {
                                    context.push('/in_call', extra: {
                                      'number': num,
                                      'name': name,
                                    });
                                  }
                                },
                                child: Container(
                                  width: _dynamicKeySize,
                                  height: _dynamicKeySize,
                                  decoration: const BoxDecoration(
                                    color: AppColors.callGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x332DBE60),
                                        blurRadius: 10,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.call_rounded,
                                    color: Colors.white,
                                    size: _dynamicKeySize * 0.48,
                                  ),
                                ),
                              ),
                              // Backspace Button
                              Expanded(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: keypadState.rawNumber.isNotEmpty
                                      ? InkWell(
                                          key: const Key('keypad_backspace_button'),
                                          borderRadius: BorderRadius.circular(30),
                                          onTap: keypadNotifier.pressBackspace,
                                          onLongPress: keypadNotifier.clearAll,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.backspace_outlined,
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                              size: _dynamicKeySize * 0.38,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(
    List<String> digits,
    List<String> letters,
    double keySize,
    bool isDark,
    KeypadNotifier notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        final digit = digits[index];
        final letter = letters[index];
        return _buildKeypadButton(digit, letter, keySize, isDark, notifier);
      }),
    );
  }

  Widget _buildKeypadButton(
    String digit,
    String letters,
    double keySize,
    bool isDark,
    KeypadNotifier notifier,
  ) {
    return InkWell(
      key: Key('keypad_digit_$digit'),
      borderRadius: BorderRadius.circular(keySize / 2),
      onTap: () => notifier.pressDigit(digit),
      onLongPress: digit == '0' ? () => notifier.pressDigit('+') : null,
      splashColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
      highlightColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
      child: Container(
        width: keySize,
        height: keySize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: TextStyle(
                fontSize: keySize * 0.44,
                fontWeight: FontWeight.w300,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                height: 1.1,
              ),
            ),
            if (digit == '1')
              Padding(
                padding: const EdgeInsets.only(top: 1.0),
                child: Icon(
                  Icons.voicemail_rounded,
                  size: keySize * 0.18,
                  color: isDark ? const Color(0xFF9E9E9E) : AppColors.lightTextSecondary,
                ),
              )
            else if (letters.isNotEmpty)
              Text(
                letters,
                style: TextStyle(
                  fontSize: keySize * 0.14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF9E9E9E) : AppColors.lightTextSecondary,
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
              )
            else
              SizedBox(height: keySize * 0.14),
          ],
        ),
      ),
    );
  }
}
