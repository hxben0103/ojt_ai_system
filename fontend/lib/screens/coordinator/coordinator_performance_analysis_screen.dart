import 'package:flutter/material.dart';
import '../../services/ojt_service.dart';
import '../../services/attendance_service.dart';
import '../../services/evaluation_service.dart';
import '../../services/prediction_service.dart';
import '../../models/ojt_record.dart';
import '../../models/evaluation.dart';

class CoordinatorPerformanceAnalysisScreen extends StatefulWidget {
  const CoordinatorPerformanceAnalysisScreen({super.key});

  @override
  State<CoordinatorPerformanceAnalysisScreen> createState() =>
      _CoordinatorPerformanceAnalysisScreenState();
}

class _CoordinatorPerformanceAnalysisScreenState
    extends State<CoordinatorPerformanceAnalysisScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String _sortBy = 'hours'; // 'hours', 'score', 'name'
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadStudentPerformance();
  }

  Future<void> _loadStudentPerformance() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final ojtRecords = await OjtService.getOjtRecords();
      final List<Map<String, dynamic>> students = [];

      for (final record in ojtRecords) {
        try {
          final summary = await AttendanceService.getAttendanceSummary(
              record.studentId);
          final evaluations = await EvaluationService.getEvaluations(
              studentId: record.studentId);

          double avgScore = 0;
          if (evaluations.isNotEmpty) {
            final scores = evaluations
                .where((e) => e.totalScore != null)
                .map((e) => e.totalScore!)
                .toList();
            if (scores.isNotEmpty) {
              avgScore = scores.reduce((a, b) => a + b) / scores.length;
            }
          }

          final completedHours =
              (summary['total_hours_completed'] ?? 0).toInt();
          final requiredHours = record.requiredHours ?? 300;
          final progress = requiredHours > 0
              ? (completedHours / requiredHours * 100).clamp(0, 100)
              : 0;

          String performanceLevel = 'Low';
          Color performanceColor = Colors.red;
          if (progress >= 100 && avgScore >= 90) {
            performanceLevel = 'Excellent';
            performanceColor = Colors.green;
          } else if (progress >= 80 && avgScore >= 75) {
            performanceLevel = 'Good';
            performanceColor = Colors.blue;
          } else if (progress >= 60 || avgScore >= 60) {
            performanceLevel = 'Average';
            performanceColor = Colors.orange;
          }

          // Get daily risk prediction
          String? riskLevel;
          double? riskProbability;
          try {
            final predictionData = await PredictionService.getDailyPrediction(record.studentId);
            if (predictionData['ai_prediction'] != null &&
                predictionData['ai_prediction']['prediction'] != null) {
              riskLevel = predictionData['ai_prediction']['prediction']['risk_level'] as String?;
              riskProbability = (predictionData['ai_prediction']['prediction']['probability'] as num?)?.toDouble();
            }
          } catch (e) {
            print('Error loading prediction for student ${record.studentId}: $e');
            // Continue without prediction data
          }

          students.add({
            'name': record.studentName ?? 'Unknown',
            'studentId': record.studentId,
            'completedHours': completedHours,
            'requiredHours': requiredHours,
            'progress': progress,
            'avgScore': avgScore,
            'evaluationCount': evaluations.length,
            'performanceLevel': performanceLevel,
            'performanceColor': performanceColor,
            'company': record.companyName ?? 'N/A',
            'riskLevel': riskLevel,
            'riskProbability': riskProbability,
          });
        } catch (e) {
          print('Error loading performance for ${record.studentName}: $e');
        }
      }

      _sortStudents(students);
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading performance: $e')),
        );
      }
    }
  }

  void _sortStudents(List<Map<String, dynamic>> students) {
    students.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'hours':
          comparison = a['completedHours'].compareTo(b['completedHours']);
          break;
        case 'score':
          comparison = a['avgScore'].compareTo(b['avgScore']);
          break;
        case 'name':
          comparison = a['name'].toString().compareTo(b['name'].toString());
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Analysis'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = false;
                }
                _sortStudents(_students);
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'hours',
                child: Row(
                  children: [
                    if (_sortBy == 'hours')
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16),
                    const SizedBox(width: 8),
                    const Text('Sort by Hours'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'score',
                child: Row(
                  children: [
                    if (_sortBy == 'score')
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16),
                    const SizedBox(width: 8),
                    const Text('Sort by Score'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    if (_sortBy == 'name')
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16),
                    const SizedBox(width: 8),
                    const Text('Sort by Name'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudentPerformance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No student data available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStudentPerformance,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      student['name'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: student['performanceColor']
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: student['performanceColor'],
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      student['performanceLevel'],
                                      style: TextStyle(
                                        color: student['performanceColor'],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Company: ${student['company']}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              // Risk Level Badge
                              if (student['riskLevel'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getRiskColor(student['riskLevel']).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _getRiskColor(student['riskLevel']),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getRiskIcon(student['riskLevel']),
                                        size: 18,
                                        color: _getRiskColor(student['riskLevel']),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'AI Risk: ${student['riskLevel']}',
                                        style: TextStyle(
                                          color: _getRiskColor(student['riskLevel']),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (student['riskProbability'] != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${(student['riskProbability'] * 100).toStringAsFixed(0)}% confidence)',
                                          style: TextStyle(
                                            color: _getRiskColor(student['riskLevel']),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      'Hours',
                                      '${student['completedHours']}/${student['requiredHours']}',
                                      Icons.access_time,
                                      Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildStatCard(
                                      'Avg Score',
                                      student['avgScore'] > 0
                                          ? student['avgScore']
                                              .toStringAsFixed(1)
                                          : 'N/A',
                                      Icons.star,
                                      Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildStatCard(
                                      'Evaluations',
                                      student['evaluationCount'].toString(),
                                      Icons.assessment,
                                      Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: (student['progress'] / 100).clamp(0, 1),
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    student['performanceColor']),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${student['progress'].toStringAsFixed(1)}% Complete',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(String? riskLevel) {
    switch (riskLevel?.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String? riskLevel) {
    switch (riskLevel?.toUpperCase()) {
      case 'HIGH':
        return Icons.warning;
      case 'MEDIUM':
        return Icons.info;
      case 'LOW':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }
}

