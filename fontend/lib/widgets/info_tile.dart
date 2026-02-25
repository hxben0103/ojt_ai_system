import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'risk_badge.dart';

/// Reusable info tile for displaying student or record information
class InfoTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final List<Widget>? additionalInfo;

  const InfoTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.additionalInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      ),
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppTheme.spacing12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        subtitle!,
                        style: AppTheme.bodySmall,
                      ),
                    ],
                    if (additionalInfo != null && additionalInfo!.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacing8),
                      Wrap(
                        spacing: AppTheme.spacing8,
                        runSpacing: AppTheme.spacing4,
                        children: additionalInfo!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (trailingText != null)
                Text(
                  trailingText!,
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.grey[600],
                  ),
                )
              else if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Specialized student info tile with risk badge and progress
class StudentInfoTile extends StatelessWidget {
  final String studentName;
  final String? course;
  final String? company;
  final int? completedHours;
  final int? requiredHours;
  final String? riskLevel;
  final VoidCallback? onTap;

  const StudentInfoTile({
    super.key,
    required this.studentName,
    this.course,
    this.company,
    this.completedHours,
    this.requiredHours,
    this.riskLevel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (completedHours != null && requiredHours != null && requiredHours! > 0)
        ? (completedHours! / requiredHours!).clamp(0.0, 1.0)
        : 0.0;

    return InfoTile(
      title: studentName,
      subtitle: [course, company].where((e) => e != null && e.isNotEmpty).join(' • '),
      onTap: onTap,
      additionalInfo: [
        if (completedHours != null && requiredHours != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '$completedHours / $requiredHours hrs',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        if (riskLevel != null)
          RiskBadge(riskLevel: riskLevel!, compact: true),
      ],
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (completedHours != null && requiredHours != null)
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: _getProgressColor(progress),
              ),
            ),
        ],
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.9) return AppTheme.successColor;
    if (progress >= 0.5) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}

