import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../dashboards/student_checklist_screen.dart';

class RestrictedAccessScreen extends StatelessWidget {
  final String title;
  final String message;

  const RestrictedAccessScreen({
    super.key,
    this.title = 'Access Restricted',
    this.message =
        'You must have an active OJT Record assigned to both a Coordinator and a Supervisor to access this feature.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: AppTheme.heading3),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[800]),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_person_rounded,
                size: 80,
                color: AppTheme.warningColor.withOpacity(0.8),
              ),
              const SizedBox(height: AppTheme.spacing24),
              Text(
                'OJT Setup Incomplete',
                style: AppTheme.heading2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                message,
                style: AppTheme.bodyLarge.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing32),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentChecklistScreen()),
                  );
                },
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Go to Application Checklist'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.warningColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing24,
                    vertical: AppTheme.spacing12,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

