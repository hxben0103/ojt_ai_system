import re
import os

filepath = r"C:\Users\ACER\Desktop\OJT _AI_SYSTEM\fontend\lib\dashboards\student_dashboard.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace _buildHeroPerformanceCard (Progress Overview)
build_hero_pattern = re.compile(r'  Widget _buildHeroPerformanceCard\(\) \{.*?(?=  // ------------------- Notification Card -------------------)', re.DOTALL)

new_hero_card = """  Widget _buildHeroPerformanceCard() {
    final hoursMap = _studentStatus?['hours'] as Map<String, dynamic>?;
    final int completedHours = (hoursMap?['completed'] as num?)?.toInt() ?? 0;
    final int requiredHours = (hoursMap?['required'] as num?)?.toInt() ?? 300;
    
    final aiInsight = _studentStatus?['ai_insight'] != null 
        ? Map<String, dynamic>.from(_studentStatus!['ai_insight'] as Map)
        : null;
        
    int computedPct = requiredHours > 0 
        ? ((completedHours / requiredHours) * 100).clamp(0, 100).toInt() 
        : 0;
    final int progressPct = (aiInsight?['score'] as num?)?.toInt() ?? computedPct;

    final attendanceMap = _studentStatus?['attendance'] as Map<String, dynamic>?;
    final int daysPresent = (attendanceMap?['days_present'] as num?)?.toInt() ?? 0;
    
    final dailyTasksMap = _studentStatus?['daily_tasks'] as Map<String, dynamic>?;
    final int completedTasks = (dailyTasksMap?['completed_tasks'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: AppTheme.studentPrimary),
              const SizedBox(width: 8),
              Text(
                'Progress Overview',
                style: AppTheme.heading3.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildProgressStat(
                  'Progress Score',
                  '$progressPct%',
                  Icons.score_rounded,
                  AppTheme.studentPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProgressStat(
                  'Completed Hours',
                  '$completedHours / $requiredHours',
                  Icons.access_time_rounded,
                  AppTheme.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
               Expanded(
                child: _buildProgressStat(
                  'Attendance Status',
                  '$daysPresent days present',
                  Icons.event_available_rounded,
                  AppTheme.infoColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProgressStat(
                  'Daily Tasks',
                  '$completedTasks tasks done',
                  Icons.task_alt_rounded,
                  AppTheme.warningColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

"""
content = build_hero_pattern.sub(new_hero_card, content)


# 2. Replace _buildExplainableAiPanel
build_ai_panel_pattern = re.compile(r'  // ── Explainable AI Panel ──.*?Widget _buildExplainableAiPanel\(\) \{.*?(?=  // ── Weekly AI Summary ──)', re.DOTALL)

new_ai_panel = """  // ── Explainable AI Panel ──
  Widget _buildExplainableAiPanel() {
    final aiInsight = _studentStatus?['ai_insight'] as Map<String, dynamic>?;
    final topReasons = (aiInsight?['top_reasons'] as List?)?.cast<String>() ?? [];
    
    if (aiInsight == null || topReasons.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: Colors.purple.shade600),
              const SizedBox(width: 8),
              Text(
                'Why this score?',
                style: AppTheme.heading3.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'AI Reasoning',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          ...topReasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.purple.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

"""
content = build_ai_panel_pattern.sub(new_ai_panel, content)


# 3. Replace _buildAttendanceIntegritySection
build_integrity_pattern = re.compile(r'  // ── Attendance Integrity Section ──.*?Widget _buildAttendanceIntegritySection\(\) \{.*?(?=  // ── 4\. Compact OJT Hours Card ──)', re.DOTALL)

new_integrity = """  // ── Attendance Integrity Section ──
  Widget _buildAttendanceIntegritySection() {
    final aiInsight = _studentStatus?['ai_insight'] as Map<String, dynamic>?;
    final integrityMap = aiInsight?['integrity'] as Map<String, dynamic>?;
    
    final int? integrityScore = (integrityMap?['integrity_score'] as num?)?.toInt();
    
    final attendanceSummary = _studentStatus?['attendance'] as Map<String, dynamic>?;
    final insideGeofence = (attendanceSummary?['inside_geofence'] as bool?) ?? true;
    final lastAttendanceDate = attendanceSummary?['last_attendance_date'] as String? ?? 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              Text(
                'Integrity Status',
                style: AppTheme.heading3.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trust Score', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      integrityScore != null ? '$integrityScore / 100' : 'N/A',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Geofence', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(insideGeofence ? Icons.check_circle : Icons.error, size: 16, color: insideGeofence ? Colors.green : Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          insideGeofence ? 'Verified' : 'Outside',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: insideGeofence ? Colors.green : Colors.red),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text('Last Record: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Expanded(
                child: Text(
                  lastAttendanceDate,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

"""
content = build_integrity_pattern.sub(new_integrity, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated student_dashboard.dart successfully')
