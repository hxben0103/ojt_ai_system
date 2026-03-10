import 'package:flutter/material.dart';
import '../../services/ojt_service.dart';
import '../../services/attendance_service.dart';
import '../../services/evaluation_service.dart';
import '../../services/prediction_service.dart';
import '../../models/ojt_record.dart';
import '../../models/evaluation.dart';
import '../../widgets/explainable_ai_card.dart';

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
  String _sortBy = 'risk'; // 'risk', 'grade', 'hours'
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

      // Load all students in parallel (Future.wait) instead of sequential for-loop
      final List<Map<String, dynamic>> students = (await Future.wait(
        ojtRecords.map((record) async {
          try {
            final summary = await AttendanceService.getAttendanceSummary(record.studentId);
            final evaluations = await EvaluationService.getEvaluations(studentId: record.studentId);

            final completedHours = (summary['total_hours_completed'] ?? 0).toInt();
            final requiredHours = record.requiredHours ?? 300;
            final progress = requiredHours > 0
                ? (completedHours / requiredHours * 100).clamp(0, 100)
                : 0;

            // Get daily AI & ML predictions
            String riskLevel = 'UNKNOWN';
            double? riskProbability;
            double? forecastedGrade;
            String? aiSummary;

            Map<String, dynamic>? predictionData;
            try {
              final rawPrediction = await PredictionService.getDailyPrediction(record.studentId);
              predictionData = Map<String, dynamic>.from(rawPrediction);

              if (predictionData['ai_prediction'] != null) {
                final ai = Map<String, dynamic>.from(predictionData['ai_prediction'] as Map);

                if (ai['ml_prediction'] != null) {
                  final ml = Map<String, dynamic>.from(ai['ml_prediction'] as Map);
                  riskLevel = ml['risk_level'] as String? ?? 'UNKNOWN';
                  riskProbability = (ml['probability'] as num?)?.toDouble();
                }

                if (ai['grading'] != null) {
                  final grading = Map<String, dynamic>.from(ai['grading'] as Map);
                  forecastedGrade = (grading['forecasted_grade'] as num?)?.toDouble();
                }

                aiSummary = ai['summary'] as String?;
              }
            } catch (e) {
              print('Error loading AI prediction for student ${record.studentId}: $e');
            }

            return <String, dynamic>{
              'name': record.studentName ?? 'Unknown',
              'studentId': record.studentId,
              'completedHours': completedHours,
              'requiredHours': requiredHours,
              'progress': progress,
              'evaluationCount': evaluations.length,
              'company': record.companyName ?? 'N/A',
              'riskLevel': riskLevel,
              'riskProbability': riskProbability,
              'forecastedGrade': forecastedGrade,
              'aiSummary': aiSummary,
              'predictionData': predictionData,
            };
          } catch (e) {
            print('Error loading performance for ${record.studentName}: $e');
            return null;
          }
        }),
      )).whereType<Map<String, dynamic>>().toList();

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
        case 'grade':
          comparison = (a['forecastedGrade'] ?? 0.0).compareTo(b['forecastedGrade'] ?? 0.0);
          break;
        case 'risk':
          int getRiskVal(String r) {
            if (r == 'HIGH') return 3;
            if (r == 'MEDIUM') return 2;
            if (r == 'LOW') return 1;
            return 0; // UNKNOWN
          }
          comparison = getRiskVal(a['riskLevel']).compareTo(getRiskVal(b['riskLevel']));
          if (comparison == 0) {
            comparison = (a['riskProbability'] ?? 0.0).compareTo(b['riskProbability'] ?? 0.0);
          }
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
                value: 'risk',
                child: Row(
                  children: [
                    if (_sortBy == 'risk')
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16),
                    const SizedBox(width: 8),
                    const Text('Sort by ML Risk'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'grade',
                child: Row(
                  children: [
                    if (_sortBy == 'grade')
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16),
                    const SizedBox(width: 8),
                    const Text('Sort by Forecasted Grade'),
                  ],
                ),
              ),
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
                                  if (student['forecastedGrade'] != null && student['forecastedGrade'] > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.blue.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        'Forecast: ${student['forecastedGrade']!.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
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
                                      'Risk Prob',
                                      student['riskProbability'] != null
                                          ? '${(student['riskProbability'] * 100).toStringAsFixed(0)}%'
                                          : 'N/A',
                                      Icons.analytics,
                                      _getRiskColor(student['riskLevel']),
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
                                    Colors.deepPurple.shade300),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${student['progress'].toStringAsFixed(1)}% Complete',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (student['predictionData'] != null) ...[
                                const SizedBox(height: 16),
                                ExplainableAiCard(
                                  prediction: student['predictionData'],
                                  isExpanded: true,
                                ),
                              ],
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

