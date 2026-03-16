import re
import os

filepath = r"C:\Users\ACER\Desktop\OJT _AI_SYSTEM\fontend\lib\dashboards\coordinator_dashboard.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update _buildStatsRow
stats_row_pattern = re.compile(r'  // --- Statistics Row \(compact 4-up\) ---.*?Widget _buildStatsRow\(\) \{.*?(?=  Widget _buildGlobalRiskInsight\(\) \{)', re.DOTALL)

new_stats_row = """  // --- Statistics Row (compact 4-up) ---
  Widget _buildStatsRow() {
    if (_isLoadingStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: LoadingSkeleton(height: 88),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Row(
        children: [
          Expanded(
            child: ModernStatCard(
              label: 'Students',
              value: '$_totalStudents',
              icon: Icons.people_rounded,
              color: AppTheme.coordinatorPrimary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CoordinatorStudentMonitor(),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: ModernStatCard(
              label: 'Flags',
              value: '$_highRiskStudents',
              icon: Icons.warning_amber_rounded,
              color: AppTheme.errorColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CoordinatorPerformanceAnalysisScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: ModernStatCard(
              label: 'Avg Grade',
              value: _averageForecastedGrade > 0
                  ? _averageForecastedGrade.toStringAsFixed(1)
                  : 'N/A',
              icon: Icons.analytics_rounded,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: ModernStatCard(
              label: 'Active',
              value: '$_activeOjt',
              icon: Icons.work_history_rounded,
              color: AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }

"""
content = stats_row_pattern.sub(new_stats_row, content)

# 2. Update _buildStudentListSection
student_list_pattern = re.compile(r'  Widget _buildStudentListSection\(\) \{.*?(?=  Widget _buildManagementGroup\(\) \{)', re.DOTALL)

new_student_list = """  Widget _buildStudentListSection() {
    if (_studentSnapshots.isEmpty) {
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
          DataColumn(label: Text('Compliance', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Integrity Flags', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _studentSnapshots.map((snapshot) {
          final riskColor = snapshot.riskLevel == 'HIGH' ? AppTheme.errorColor : (snapshot.riskLevel == 'MEDIUM' ? AppTheme.warningColor : AppTheme.successColor);
          
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: riskColor.withOpacity(0.1),
                      child: Text(
                        snapshot.studentName[0].toUpperCase(),
                        style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        snapshot.studentName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${(snapshot.completionRatio * 100).toInt()}% Done", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text("${snapshot.approvedHours.toStringAsFixed(1)} hrs", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              DataCell(
                snapshot.isFlagged
                    ? IntegrityBadge.flagged(isOut: snapshot.isLatestOut, isCompact: true)
                    : IntegrityBadge.trust(flaggedCount: snapshot.lateCount, isCompact: true),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onPressed: () => _showStudentDetail(snapshot),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

"""
content = student_list_pattern.sub(new_student_list, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated coordinator_dashboard.dart successfully')

