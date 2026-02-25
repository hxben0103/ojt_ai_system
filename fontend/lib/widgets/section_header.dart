import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Centralized section header for dashboards
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing24,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: Colors.black54,
                ),
                const SizedBox(width: AppTheme.spacing8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.heading3,
                ),
              ),
              if (trailing != null) trailing!,
              if (action != null) action!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppTheme.spacing4),
            Padding(
              padding: EdgeInsets.only(left: icon != null ? 28.0 : 0),
              child: Text(
                subtitle!,
                style: AppTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

