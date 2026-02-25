import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'section_header.dart';

/// Shared scaffold for dashboard-style screens with
/// consistent padding, scroll behavior, and optional pull-to-refresh.
class DashboardScaffold extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final List<Widget>? actions;

  const DashboardScaffold({
    super.key,
    required this.title,
    required this.color,
    required this.children,
    this.onRefresh,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: children,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: actions,
      ),
      body: onRefresh != null
          ? RefreshIndicator(onRefresh: onRefresh!, child: body)
          : body,
    );
  }
}

/// Gradient header used at the top of dashboards (role, greeting, quick meta).
class DashboardHeader extends StatelessWidget {
  final Color color;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const DashboardHeader({
    super.key,
    required this.color,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppTheme.spacing16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.heading2.copyWith(color: Colors.white),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    subtitle!,
                    style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTheme.spacing8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Responsive grid for small stat cards. On phones this is typically 2-up.
class StatGrid extends StatelessWidget {
  final List<Widget> children;

  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final crossAxisCount = maxWidth > 720
            ? 3
            : maxWidth > 480
                ? 2
                : 2;
        final itemWidth =
            (maxWidth - (AppTheme.spacing12 * (crossAxisCount - 1))) /
                crossAxisCount;

        return Wrap(
          spacing: AppTheme.spacing12,
          runSpacing: AppTheme.spacing12,
          children: children
              .map(
                (c) => SizedBox(
                  width: itemWidth,
                  child: c,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

/// Simple reusable empty state widget.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey[400]),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              title,
              style: AppTheme.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              message,
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.spacing24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

