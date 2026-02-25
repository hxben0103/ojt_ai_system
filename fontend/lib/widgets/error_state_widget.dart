import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// A reusable error state widget that shows an icon, title, message,
/// and an optional retry button.
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.icon = Icons.wifi_off_rounded,
    this.retryLabel = 'Try Again',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              title,
              style: AppTheme.heading3.copyWith(color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              message,
              style: AppTheme.bodySmall.copyWith(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spacing24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel ?? 'Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing24,
                    vertical: AppTheme.spacing12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact inline banner for cached/stale data warnings.
class StaleBanner extends StatelessWidget {
  final String message;
  const StaleBanner({super.key, this.message = 'Showing cached data — you appear to be offline'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(
          left: BorderSide(color: Colors.amber.shade600, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: Colors.amber.shade700),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
