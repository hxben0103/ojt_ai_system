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
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: Colors.blueGrey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: Colors.blueGrey.shade600),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  title,
                  style: AppTheme.heading3.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (headerAction != null) headerAction!,
              ],
            ),
          ),
          Divider(height: 1, color: Colors.blueGrey.shade50),
          Padding(
            padding: padding ?? const EdgeInsets.all(0),
            child: table,
          ),
        ],
      ),
    );
  }
}

