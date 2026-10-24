import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Samsung One UI signature fast-scroll vertical alphabet index with bubble magnifier
class AlphabetScrubber extends StatefulWidget {
  final List<String> availableLetters;
  final ValueChanged<String> onLetterSelected;

  const AlphabetScrubber({
    super.key,
    required this.availableLetters,
    required this.onLetterSelected,
  });

  @override
  State<AlphabetScrubber> createState() => _AlphabetScrubberState();
}

class _AlphabetScrubberState extends State<AlphabetScrubber> {
  static const List<String> _alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  String? _activeLetter;
  double _bubbleY = 0.0;
  bool _isDragging = false;

  void _updateLetter(Offset localPosition, double totalHeight) {
    if (totalHeight <= 0) return;
    final itemHeight = totalHeight / _alphabet.length;
    final index = (localPosition.dy / itemHeight).floor().clamp(0, _alphabet.length - 1);
    final letter = _alphabet[index];

    if (_activeLetter != letter) {
      HapticFeedback.selectionClick();
      final maxY = (totalHeight - 24.0).clamp(24.0, double.infinity);
      setState(() {
        _activeLetter = letter;
        _bubbleY = localPosition.dy.clamp(24.0, maxY);
      });
      widget.onLetterSelected(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.availableLetters.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Alphabet Vertical Column
        LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;

            return GestureDetector(
              onVerticalDragStart: (details) {
                setState(() => _isDragging = true);
                _updateLetter(details.localPosition, height);
              },
              onVerticalDragUpdate: (details) {
                _updateLetter(details.localPosition, height);
              },
              onVerticalDragEnd: (_) {
                setState(() {
                  _isDragging = false;
                  _activeLetter = null;
                });
              },
              onTapDown: (details) {
                setState(() => _isDragging = true);
                _updateLetter(details.localPosition, height);
              },
              onTapUp: (_) {
                setState(() {
                  _isDragging = false;
                  _activeLetter = null;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 16,
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: _isDragging
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _alphabet.map((letter) {
                    final hasContacts = widget.availableLetters.contains(letter);
                    final isCurrent = _activeLetter == letter;

                    return Expanded(
                      child: Center(
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: isCurrent || hasContacts
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isCurrent
                                ? AppColors.primaryBlue
                                : (hasContacts
                                    ? (isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary)
                                    : (isDark
                                        ? const Color(0xFF48484A)
                                        : const Color(0xFFC7C7CC))),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
        // Floating Bubble Magnifier Preview (One UI Style)
        if (_isDragging && _activeLetter != null)
          Positioned(
            right: 28,
            top: _bubbleY - 24,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _activeLetter!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
