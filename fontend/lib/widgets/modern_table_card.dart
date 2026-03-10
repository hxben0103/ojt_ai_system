import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// A standardized card wrapper for data lists and tables.
/// Provides consistent headers, padding, and elevation.
class ModernTableCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? headerAction;
  final Widget table;
  final EdgeInsets? padding;

  const ModernTableCard({
    super.key,
    required this.title,
    this.icon,
    this.headerAction,
    required this.table,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: AppTheme.heading3.copyWith(fontSize: 16),
                ),
                const Spacer(),
                if (headerAction != null) headerAction!,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: padding ?? const EdgeInsets.all(0),
            child: table,
          ),
        ],
      ),
    );
  }
}
