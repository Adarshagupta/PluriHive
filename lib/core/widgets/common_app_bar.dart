import 'package:flutter/material.dart';
import '../theme/app_constants.dart';

/// Standardized SliverAppBar for consistent design across screens
class CommonSliverAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? iconData;
  final List<Widget>? actions;
  final double expandedHeight;
  final bool pinned;

  const CommonSliverAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.iconData,
    this.actions,
    this.expandedHeight = AppConstants.appBarExpandedHeight,
    this.pinned = true,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: pinned,
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.primary,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
                vertical: AppConstants.spacingMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (iconData != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Icon(
                        iconData,
                        color: Colors.white,
                        size: AppConstants.iconLg,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppConstants.spacingSm),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
