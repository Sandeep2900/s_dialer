import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Reusable Samsung One UI Collapsible Header (SliverAppBar)
/// Features large expanding/collapsing title and top action icons.
class OneUiHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? bottom;
  final double expandedHeight;
  final bool showSearchAction;
  final VoidCallback? onSearchTap;

  const OneUiHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
    this.expandedHeight = AppDimensions.oneUiExpandedHeaderHeight,
    this.showSearchAction = false,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: expandedHeight,
      collapsedHeight: AppDimensions.oneUiCollapsedHeaderHeight,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        if (showSearchAction)
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: onSearchTap,
          ),
        ...?actions,
        const SizedBox(width: AppDimensions.paddingS),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Calculate collapse ratio: 0.0 (fully collapsed) to 1.0 (fully expanded)
          final minHeight = AppDimensions.oneUiCollapsedHeaderHeight +
              MediaQuery.of(context).padding.top;
          final maxHeight = expandedHeight + MediaQuery.of(context).padding.top;
          final currentHeight = constraints.maxHeight;

          final denom = maxHeight - minHeight;
          final ratio = denom > 0 && currentHeight.isFinite
              ? ((currentHeight - minHeight) / denom).clamp(0.0, 1.0)
              : 1.0;

          return FlexibleSpaceBar(
            centerTitle: false,
            titlePadding: EdgeInsets.zero,
            title: Padding(
              padding: EdgeInsets.only(
                left: AppDimensions.paddingL,
                right: (140.0 * (1 - ratio) + AppDimensions.paddingL * ratio).clamp(AppDimensions.paddingL, 160.0),
                bottom: 12.0 * (1 - ratio) + 16.0 * ratio,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 19.0 + (13.0 * ratio), // 19px collapsed -> 32px expanded
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (subtitle != null && ratio > 0.4)
                      Opacity(
                        opacity: ((ratio - 0.4) / 0.6).clamp(0.0, 1.0),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
