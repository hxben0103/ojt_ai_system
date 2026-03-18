import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
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
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = true;
  String _sortBy = 'risk'; // 'risk', 'grade', 'hours', 'name'
  bool _sortAscending = false;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadStudentPerformance();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilterAndSort();
    });
  }

  Future<void> _loadStudentPerformance() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final currentUser = await AuthService.getCurrentUser();
      if (!mounted) return;
      
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        // Optionally show a message to the user that they need to be logged in
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in. Cannot load performance data.')),
          );
        }
        return;
      }

      final ojtRecords = await OjtService.getOjtRecords(
        coordinatorId: currentUser.userId,
      );
      
      debugPrint('[CoordinatorPerformanceAnalysis] Loaded ${ojtRecords.length} OJT records');

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

                // Try to get risk level from ml_prediction object OR top-level risk_level key
                if (ai['ml_prediction'] != null) {
                  final ml = Map<String, dynamic>.from(ai['ml_prediction'] as Map);
                  riskLevel = (ml['risk_level'] as String? ?? ai['risk_level'] as String? ?? 'UNKNOWN').toUpperCase();
                  riskProbability = (ml['probability'] as num? ?? ml['confidence'] as num? ?? ai['probability'] as num?)?.toDouble();
                } else {
                  riskLevel = (ai['risk_level'] as String? ?? 'UNKNOWN').toUpperCase();
                  riskProbability = (ai['probability'] as num? ?? ai['confidence'] as num?)?.toDouble();
                }

                if (ai['grading'] != null) {
                  final grading = Map<String, dynamic>.from(ai['grading'] as Map);
                  forecastedGrade = (grading['forecasted_grade'] as num?)?.toDouble();
                }

                // AI Explanation (Gemma Narrative)
                aiSummary = ai['gemma_explanation'] as String? ?? ai['summary'] as String? ?? ai['explanation'] as String?;
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

      if (!mounted) return;
      setState(() {
        _students = students;
        _applyFilterAndSort();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

  void _applyFilterAndSort() {
    List<Map<String, dynamic>> filtered = _students.where((student) {
      final name = (student['name'] as String).toLowerCase();
      final company = (student['company'] as String).toLowerCase();
      return name.contains(_searchQuery) || company.contains(_searchQuery);
    }).toList();

    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
          break;
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

    if (!mounted) return;
    setState(() {
      _filteredStudents = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search student, HTE, or company...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : const Text('Performance Analysis'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _isSearching = false;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = value == 'name' ? true : false;
                }
                _applyFilterAndSort();
              });
            },
            itemBuilder: (context) => [
              _buildSortItem('name', 'Sort by Name', Icons.sort_by_alpha),
              _buildSortItem('risk', 'Sort by ML Risk', Icons.warning_amber_rounded),
              _buildSortItem('grade', 'Sort by Forecasted Grade', Icons.trending_up),
              _buildSortItem('hours', 'Sort by Hours', Icons.access_time),
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
            : _filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty 
                              ? 'No students match "$_searchQuery"'
                              : 'No student data available',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadStudentPerformance,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
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
                                        'AI Assessment: ${_getFriendlyRisk(student['riskLevel'])}',
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

  PopupMenuItem<String> _buildSortItem(String value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: _sortBy == value ? Colors.deepPurple : Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (_sortBy == value)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: Colors.deepPurple,
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
      case 'HIGH': return Icons.warning_amber_rounded;
      case 'MEDIUM': return Icons.info_outline;
      case 'LOW': return Icons.check_circle_outline;
      default: return Icons.help_outline;
    }
  }

  String _getFriendlyRisk(String? riskLevel) {
    switch (riskLevel?.toUpperCase()) {
      case 'HIGH': return 'Needs Attention';
      case 'MEDIUM': return 'Fair Standing';
      case 'LOW': return 'Good Standing';
      default: return 'Pending Review';
    }
  }
}
