import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

/// Main Samsung One UI Navigation Shell with bottom navigation bar and floating keypad trigger
class MainNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget>? children;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
    this.children,
  });

  void _onTabSelected(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      extendBody: true,
      body: children != null
          ? SmoothBranchContainer(
              currentIndex: currentIndex,
              children: children!,
            )
          : navigationShell,
      // Floating Keypad button on Recents (tab 1) and Contacts (tab 2) with smooth scale/fade pop
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
        child: currentIndex == 1
            ? SizedBox(
                width: 48,
                height: 48,
                child: FloatingActionButton(
                  key: const ValueKey('floating_keypad_fab'),
                  heroTag: 'floating_keypad_button',
                  backgroundColor: AppColors.callGreen,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: const CircleBorder(),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _onTabSelected(0);
                  },
                  child: const Icon(Icons.dialpad_rounded, size: 24),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('empty_fab')),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 64,
          color: Colors.transparent,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom > 0 ? 8 : 12,
            top: 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: 272,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161618).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Smoothly sliding active pill indicator
                        Row(
                  children: List.generate(3, (i) {
                    return Expanded(
                      child: AnimatedOpacity(
                        opacity: currentIndex == i ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C30)
                                : const Color(0xFFE6E6EA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.04),
                              width: 0.6,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.3 : 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                // Interactive tab labels and icons on top
                Row(
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.dialpad_rounded,
                      label: 'Keypad',
                      isSelected: currentIndex == 0,
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.phone_callback_rounded,
                      label: 'Recents',
                      isSelected: currentIndex == 1,
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: currentIndex == 2
                          ? Icons.person_rounded
                          : Icons.person_outline_rounded,
                      label: 'Contacts',
                      isSelected: currentIndex == 2,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
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

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    final activeColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final inactiveColor =
        isDark ? const Color(0xFFA4A4A6) : const Color(0xFF6E6E73);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabSelected(index),
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                const SizedBox(height: 1.5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Smooth branch container providing silky fade and slide transitions between tabs with lazy branch loading
class SmoothBranchContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const SmoothBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  @override
  State<SmoothBranchContainer> createState() => _SmoothBranchContainerState();
}

class _SmoothBranchContainerState extends State<SmoothBranchContainer> {
  final Set<int> _loadedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadedIndices.add(widget.currentIndex);
  }

  @override
  void didUpdateWidget(SmoothBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadedIndices.add(widget.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (index) {
        final isCurrent = index == widget.currentIndex;
        final isLoaded = _loadedIndices.contains(index);

        // Directional subtle slide: items to the left slide slightly left, items to right slide right
        final offset = isCurrent
            ? Offset.zero
            : Offset(index < widget.currentIndex ? -0.06 : 0.06, 0.0);

        return AnimatedOpacity(
          opacity: isCurrent ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: offset,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: IgnorePointer(
              ignoring: !isCurrent,
              child: TickerMode(
                enabled: isCurrent,
                child: isLoaded
                    ? widget.children[index]
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        );
      }),
    );
  }
}

