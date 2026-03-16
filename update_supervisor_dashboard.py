import re
import os

filepath = r"C:\Users\ACER\Desktop\OJT _AI_SYSTEM\fontend\lib\dashboards\supervisor_dashboard.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update _buildEvaluationInsight
eval_pattern = re.compile(r'  Widget _buildEvaluationInsight\(SupervisorProvider provider\) \{.*?(?=  Widget _buildStudentTable)', re.DOTALL)

new_eval = """  Widget _buildEvaluationInsight(SupervisorProvider provider) {
    if (provider.isLoadingStudents) return const SizedBox.shrink();
    
    final bool allDone = provider.pendingEvaluations == 0 && provider.totalAssigned > 0;
    final int needingAttention = provider.highRiskStudents;
    
    return InsightCard(
      title: "Mentoring Recommendations",
      subtitle: "Review feedback and performance monitoring",
      icon: Icons.fact_check_rounded,
      statusLabel: needingAttention > 0 ? "$needingAttention Needs Attention" : (allDone ? "ALL COMPLETED" : "${provider.pendingEvaluations ?? 0} Pending"),
      statusColor: needingAttention > 0 ? AppTheme.errorColor : (allDone ? AppTheme.successColor : AppTheme.warningColor),
      progressValue: provider.totalAssigned > 0 ? ((provider.totalAssigned - provider.pendingEvaluations) / provider.totalAssigned).clamp(0.0, 1.0) : 1.0,
      insights: [
        if (needingAttention > 0) "$needingAttention students are flagging poor attendance or low progress scores.",
        if (provider.pendingEvaluations > 0) "${provider.pendingEvaluations ?? 0} students awaiting end-of-term evaluation.",
        if (provider.totalAssigned > 0) "Total assigned students: ${provider.totalAssigned ?? 0}",
      ],
      recommendation: needingAttention > 0 
          ? "Immediate 1-on-1 mentoring recommended for flagged students." 
          : (provider.pendingEvaluations > 0 ? "Complete pending evaluations to finalize student grades." : "All assigned students have been evaluated for this term."),
    );
  }

"""

# 2. Update _buildStudentTable
student_table_pattern = re.compile(r'  Widget _buildStudentTable\(SupervisorProvider provider\) \{.*?(?=  Widget _buildFlagIndicator)', re.DOTALL)

new_student_table = """  Widget _buildStudentTable(SupervisorProvider provider) {
    if (provider.assignedStudents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No students assigned yet.', style: AppTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
        columnSpacing: 24,
        horizontalMargin: 16,
        dataRowMaxHeight: 65,
        dataRowMinHeight: 60,
        columns: const [
          DataColumn(label: Text('Student', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Attendance Consistency', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Pending Evaluations', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: provider.assignedStudents.map((record) {
          final Attendance? todayRecord = provider.todayAttendanceMap[record.studentId];
          final hasFlag = todayRecord?.verificationStatus == 'FLAGGED';
          
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.supervisorPrimary.withOpacity(0.1),
                      child: Text(
                        (record.studentName ?? "S")[0].toUpperCase(),
                        style: TextStyle(color: AppTheme.supervisorPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        record.studentName ?? 'Unknown Student',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Row(
                  children: [
                    Icon(hasFlag ? Icons.warning_amber_rounded : Icons.check_circle_outline, 
                         color: hasFlag ? AppTheme.errorColor : AppTheme.successColor, size: 16),
                    const SizedBox(width: 4),
                    Text(hasFlag ? 'Poor' : 'Consistent', 
                         style: TextStyle(fontSize: 13, color: hasFlag ? AppTheme.errorColor : AppTheme.successColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              DataCell(
                 Text(record.status == 'Evaluation Pending' ? '1 Pending' : 'None', 
                     style: TextStyle(fontSize: 13, color: record.status == 'Evaluation Pending' ? AppTheme.warningColor : Colors.grey.shade700)),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupervisorEvaluationFormScreen())),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

"""

content = eval_pattern.sub(new_eval, content)
content = student_table_pattern.sub(new_student_table, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated supervisor_dashboard.dart successfully')
