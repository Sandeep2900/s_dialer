import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Reusable Samsung One UI Swipe-to-Call / Swipe-to-SMS tile
/// Swipe right -> Call (Green)
/// Swipe left  -> SMS  (Blue)
class SwipeToCallTile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeRight; // Call
  final VoidCallback? onSwipeLeft;  // SMS
  final double thresholdRatio;      // Percentage of width to trigger action (default: 35%)
  final bool enabled;
  final Color? backgroundColor;

  const SwipeToCallTile({
    super.key,
    required this.child,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.thresholdRatio = 0.35,
    this.enabled = true,
    this.backgroundColor,
  });

  @override
  State<SwipeToCallTile> createState() => SwipeToCallTileState();
}

class SwipeToCallTileState extends State<SwipeToCallTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _hasTriggeredHaptic = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _dragOffset = _animation.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double totalWidth) {
    if (!widget.enabled || totalWidth <= 0) return;

    setState(() {
      _dragOffset += details.primaryDelta ?? 0.0;
      // Clamp between -totalWidth and +totalWidth
      _dragOffset = _dragOffset.clamp(-totalWidth, totalWidth);

      final ratio = (_dragOffset.abs() / totalWidth);
      if (ratio >= widget.thresholdRatio && !_hasTriggeredHaptic) {
        _hasTriggeredHaptic = true;
        HapticFeedback.mediumImpact();
      } else if (ratio < widget.thresholdRatio && _hasTriggeredHaptic) {
        _hasTriggeredHaptic = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, double totalWidth) {
    if (!widget.enabled || totalWidth <= 0) return;

    final ratio = _dragOffset.abs() / totalWidth;
    final velocity = details.primaryVelocity ?? 0.0;
    final isFlingRight = velocity > 500;
    final isFlingLeft = velocity < -500;

    final shouldTriggerRight =
        (_dragOffset > 0 && ratio >= widget.thresholdRatio) || isFlingRight;
    final shouldTriggerLeft =
        (_dragOffset < 0 && ratio >= widget.thresholdRatio) || isFlingLeft;

    if (shouldTriggerRight && widget.onSwipeRight != null) {
      widget.onSwipeRight!();
    } else if (shouldTriggerLeft && widget.onSwipeLeft != null) {
      widget.onSwipeLeft!();
    }

    _animateBack();
  }

  void _animateBack() {
    _hasTriggeredHaptic = false;
    _animation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery instead of LayoutBuilder — LayoutBuilder as the root of a
    // sliver list item causes the 'slot == null' assertion crash on Android.
    final totalWidth = MediaQuery.sizeOf(context).width;
    final isSwipingRight = _dragOffset > 0;
    final progress = totalWidth > 0
        ? (_dragOffset.abs() / totalWidth).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Call'): () {
          widget.onSwipeRight?.call();
        },
        CustomSemanticsAction(label: 'Send message'): () {
          widget.onSwipeLeft?.call();
        },
      },
      child: GestureDetector(
        onHorizontalDragUpdate: (details) =>
            _onHorizontalDragUpdate(details, totalWidth),
        onHorizontalDragEnd: (details) =>
            _onHorizontalDragEnd(details, totalWidth),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Revealed Background
            Positioned.fill(
              child: Container(
                color: isSwipingRight
                    ? AppColors.swipeCallBackground
                    : AppColors.swipeMessageBackground,
                alignment: isSwipingRight
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Opacity(
                  opacity: (progress * 2.5).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.6 + (0.5 * progress).clamp(0.0, 0.5),
                    child: Icon(
                      isSwipingRight
                          ? Icons.call_rounded
                          : Icons.message_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
            // Sliding Content
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Container(
                color: widget.backgroundColor ??
                    Theme.of(context).scaffoldBackgroundColor,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
