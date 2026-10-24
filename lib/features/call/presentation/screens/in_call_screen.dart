import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/phone_number_formatter.dart';
import '../../../../core/services/telephony_service.dart';
import '../providers/call_provider.dart';

class InCallScreen extends ConsumerStatefulWidget {
  final String? initialNumber;
  final String? initialName;

  const InCallScreen({
    super.key,
    this.initialNumber,
    this.initialName,
  });

  @override
  ConsumerState<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends ConsumerState<InCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleCallEnded({bool immediate = false}) {
    if (_hasPopped) return;
    _hasPopped = true;
    final delay = immediate ? const Duration(milliseconds: 100) : const Duration(milliseconds: 500);
    Future.delayed(delay, () {
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/keypad');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);
    final callNotifier = ref.read(callProvider.notifier);

    // Auto-pop when call ends or status reset to idle
    if (callState.isEnded || (callState.status == 'idle' && !_hasPopped)) {
      _handleCallEnded();
    }

    final rawNumber = callState.number.isNotEmpty
        ? callState.number
        : (widget.initialNumber ?? '');
    final displayName = callState.name ?? widget.initialName;
    final formattedNumber = PhoneNumberFormatter.format(rawNumber);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Allow user to minimize screen back to app without hanging up
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF070A0F),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.2,
              colors: [
                Color(0xFF141F36),
                Color(0xFF090D15),
                Color(0xFF05070B),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top Action Bar (Minimize & SIM Card Info)
                _buildTopBar(context, callState.simInfo),

                const SizedBox(height: 20),

                // Caller Display (Name, Formatted Number, Call Status / Timer)
                _buildCallerInfo(
                  displayName: displayName,
                  formattedNumber: formattedNumber,
                  callState: callState,
                ),

                const Spacer(),

                // Center Area: Avatar or In-Call Keypad (for DTMF / IVR)
                if (callState.isKeypadVisible)
                  _buildInCallKeypad(callNotifier)
                else
                  _buildCallerAvatar(
                    displayName: displayName,
                    number: rawNumber,
                    callState: callState,
                  ),

                const Spacer(),

                // In-Call Action Grid (Mute, Speaker, Hold) or Quick Decline Message for incoming calls
                if (!callState.isRinging)
                  _buildActionGrid(callState, callNotifier)
                else
                  _buildIncomingCallQuickActions(context, callNotifier, rawNumber),

                const SizedBox(height: 36),

                // Bottom Call Controls (End Call or Answer/Decline if incoming)
                _buildBottomControls(context, callState, callNotifier),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String simInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white70, size: 32),
            tooltip: 'Minimize call',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/keypad');
              }
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sim_card_rounded,
                    size: 14, color: AppColors.callGreen),
                const SizedBox(width: 6),
                Text(
                  simInfo,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balancing width
        ],
      ),
    );
  }

  Widget _buildCallerInfo({
    required String? displayName,
    required String formattedNumber,
    required dynamic callState,
  }) {
    final title = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName
        : (formattedNumber.isNotEmpty ? formattedNumber : 'Unknown Caller');
    final subtitle = (displayName != null && displayName.trim().isNotEmpty)
        ? formattedNumber
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Status badge / live call duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusBadgeColor(callState.status),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (callState.isConnected) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.callGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  callState.statusText,
                  style: TextStyle(
                    color: _getStatusTextColor(callState.status),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusBadgeColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.callGreen.withValues(alpha: 0.15);
      case 'disconnected':
        return Colors.red.withValues(alpha: 0.2);
      case 'holding':
        return Colors.orange.withValues(alpha: 0.2);
      default:
        return Colors.white.withValues(alpha: 0.08);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.callGreen;
      case 'disconnected':
        return Colors.redAccent;
      case 'holding':
        return Colors.orangeAccent;
      default:
        return Colors.white70;
    }
  }

  Widget _buildCallerAvatar({
    required String? displayName,
    required String number,
    required dynamic callState,
  }) {
    final initial = (displayName != null && displayName.isNotEmpty)
        ? displayName[0].toUpperCase()
        : (number.isNotEmpty ? '#' : '?');

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (callState.isRinging)
              Container(
                width: 144 * _pulseAnimation.value,
                height: 144 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.callGreen.withValues(alpha: (1.04 - _pulseAnimation.value).clamp(0.0, 1.0) * 12),
                    width: 2.5,
                  ),
                ),
              ),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: callState.isRinging
                      ? const [Color(0xFF00B09B), Color(0xFF96C93D)]
                      : const [Color(0xFF2575FC), Color(0xFF6A11CB)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (callState.isRinging ? AppColors.callGreen : const Color(0xFF2575FC))
                        .withValues(alpha: 0.4),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInCallKeypad(CallNotifier callNotifier) {
    final digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: digits.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((digit) {
                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    callNotifier.sendDtmf(digit);
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      digit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionGrid(dynamic callState, CallNotifier callNotifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: callState.isMuted
                    ? Icons.mic_off_rounded
                    : Icons.mic_rounded,
                label: 'Mute',
                isActive: callState.isMuted,
                onTap: callNotifier.toggleMute,
              ),
              _buildActionButton(
                icon: Icons.dialpad_rounded,
                label: 'Keypad',
                isActive: callState.isKeypadVisible,
                onTap: callNotifier.toggleKeypad,
              ),
              _buildActionButton(
                icon: callState.isSpeaker
                    ? Icons.volume_up_rounded
                    : Icons.volume_down_rounded,
                label: 'Speaker',
                isActive: callState.isSpeaker,
                onTap: callNotifier.toggleSpeaker,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: callState.isHold
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                label: callState.isHold ? 'Unhold' : 'Hold',
                isActive: callState.isHold,
                onTap: callNotifier.toggleHold,
              ),
              _buildActionButton(
                icon: Icons.person_add_rounded,
                label: 'Add call',
                isActive: false,
                onTap: () {
                  context.push('/contacts');
                },
              ),
              _buildActionButton(
                icon: Icons.fiber_manual_record_rounded,
                label: 'Record',
                isActive: false,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Call recording will start'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isActive ? Colors.black : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingCallQuickActions(
    BuildContext context,
    CallNotifier callNotifier,
    String number,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: InkWell(
        onTap: () => _showQuickDeclineBottomSheet(context, callNotifier, number),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.message_outlined, size: 16, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                'Send message & decline',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickDeclineBottomSheet(
    BuildContext context,
    CallNotifier callNotifier,
    String number,
  ) {
    final messages = [
      "Can't talk now. What's up?",
      "I'll call you right back.",
      "In a meeting. Please text.",
      "Call you later.",
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161618),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Quick Decline Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...messages.map((msg) => ListTile(
                      title: Text(
                        msg,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      trailing: const Icon(Icons.send_rounded, size: 18, color: AppColors.primaryBlue),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (number.isNotEmpty) {
                          ref.read(telephonyServiceProvider).sendSms(number, msg);
                        }
                        callNotifier.hangup();
                        _handleCallEnded(immediate: true);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    dynamic callState,
    CallNotifier callNotifier,
  ) {
    if (callState.isRinging) {
      // Incoming Call: Big Answer & Decline Buttons with Labels
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 52.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Green Answer Button
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    callNotifier.answer();
                  },
                  borderRadius: BorderRadius.circular(42),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.callGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.callGreen.withValues(alpha: 0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Answer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            // Red Decline Button
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    callNotifier.hangup();
                    _handleCallEnded(immediate: true);
                  },
                  borderRadius: BorderRadius.circular(42),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.endCallRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.endCallRed.withValues(alpha: 0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_end_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Decline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Outgoing or Active Call: Single Big Red End Call Button
    return InkWell(
      onTap: () {
        HapticFeedback.heavyImpact();
        callNotifier.hangup();
        _handleCallEnded(immediate: true);
      },
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 74,
        height: 74,
        decoration: const BoxDecoration(
          color: AppColors.endCallRed,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x66FF3B30),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.call_end_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}
