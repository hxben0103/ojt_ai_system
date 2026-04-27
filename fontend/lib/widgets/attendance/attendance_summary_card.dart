import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../core/app_theme.dart';

class AttendanceSummaryCard extends StatelessWidget {
  final Attendance? attendance;
  final String Function(String?) formatTime;

  const AttendanceSummaryCard({
    super.key,
    required this.attendance,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    if (attendance == null) return const SizedBox.shrink();

    final double credited = attendance!.regularHours ?? 0.0;
    final int deduction = attendance!.deductionMinutes ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Attendance Summary", style: AppTheme.heading3),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              children: [
                Expanded(child: _buildSummaryItem("Morning In", formatTime(attendance!.morningIn))),
                Expanded(child: _buildSummaryItem("Morning Out", formatTime(attendance!.morningOut))),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                Expanded(child: _buildSummaryItem("Afternoon In", formatTime(attendance!.afternoonIn))),
                Expanded(child: _buildSummaryItem("Afternoon Out", formatTime(attendance!.afternoonOut))),
              ],
            ),
            if (attendance!.overtimeIn != null) ...[
              const SizedBox(height: AppTheme.spacing12),
              Row(
                children: [
                  Expanded(child: _buildSummaryItem("Overtime In", formatTime(attendance!.overtimeIn))),
                  Expanded(child: _buildSummaryItem("Overtime Out", formatTime(attendance!.overtimeOut))),
                ],
              ),
            ],
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    "Late Deduction", 
                    "$deduction mins", 
                    icon: Icons.timer_off_outlined, 
                    color: deduction > 0 ? AppTheme.errorColor : null
                  )
                ),
                Expanded(
                  child: _buildSummaryItem(
                    "Credited Hours", 
                    "${credited.toStringAsFixed(1)} hrs", 
                    icon: Icons.check_circle_outline, 
                    color: AppTheme.successColor
                  )
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              "Note: Early arrival gives no extra credit. Late arrivals are rounded to the next 30-minute block.",
              style: AppTheme.caption.copyWith(fontStyle: FontStyle.italic),
            ),
            if (attendance!.coordinatorComment != null) ...[
              const SizedBox(height: AppTheme.spacing16),
              const Divider(),
              const SizedBox(height: AppTheme.spacing8),
              _buildCoordinatorFeedback(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinatorFeedback() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.comment_outlined, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                "Coordinator Feedback",
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            attendance!.coordinatorComment!,
            style: AppTheme.bodyMedium,
          ),
          if (attendance!.coordinatorCommentAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DateFormat('MMM d, h:mm a').format(attendance!.coordinatorCommentAt!),
                style: AppTheme.caption.copyWith(fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {IconData? icon, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.bodySmall),
        const SizedBox(height: 4),
        Row(
          children: [
            if (icon != null) Icon(icon, size: 16, color: color ?? Colors.blueGrey),
            if (icon != null) const SizedBox(width: 4),
            Text(
              value.isEmpty ? "--:--" : value,
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.bold, 
                color: color
              ),
            ),
          ],
        ),
      ],
    );
  }
}
