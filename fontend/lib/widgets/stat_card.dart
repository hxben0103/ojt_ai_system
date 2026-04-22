import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Reusable stat card for displaying key metrics with a premium look
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? trend; // e.g. "+5%" or "-2%"
  final bool? trendPositive; // true for green, false for red
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.trend,
    this.trendPositive,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppTheme.studentPrimary;
    
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: Colors.blueGrey.shade50, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: cardColor,
                        size: 24,
                      ),
                    ),
                    if (trend != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (trendPositive ?? true) 
                              ? AppTheme.successColor.withOpacity(0.08)
                              : AppTheme.errorColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (trendPositive ?? true) ? Icons.trending_up : Icons.trending_down,
                              color: (trendPositive ?? true) ? AppTheme.successColor : AppTheme.errorColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trend!,
                              style: AppTheme.caption.copyWith(
                                color: (trendPositive ?? true)
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (onTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: Colors.blueGrey.shade300,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  value,
                  style: AppTheme.heading1.copyWith(
                    fontSize: 32,
                    color: Colors.blueGrey.shade900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title.toUpperCase(),
                  style: AppTheme.caption.copyWith(
                    color: Colors.blueGrey.shade500,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    fontSize: 10,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.blueGrey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


