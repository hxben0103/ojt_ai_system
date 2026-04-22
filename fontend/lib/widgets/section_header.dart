import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Centralized section header for dashboards
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? action;
  final Color? color;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.action,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (color ?? AppTheme.studentPrimary).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: color ?? AppTheme.studentPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: AppTheme.heading3.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing!,
              if (action != null) action!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: icon != null ? 38 : 0),
              child: Text(
                subtitle!,
                style: AppTheme.bodySmall.copyWith(color: Colors.blueGrey.shade400),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


