import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/evaluation_service.dart';
import '../../models/evaluation.dart';
import '../../services/auth_service.dart';

class CoordinatorSupervisorFeedbackScreen extends StatefulWidget {
  const CoordinatorSupervisorFeedbackScreen({super.key});

  @override
  State<CoordinatorSupervisorFeedbackScreen> createState() =>
      _CoordinatorSupervisorFeedbackScreenState();
}

class _CoordinatorSupervisorFeedbackScreenState
    extends State<CoordinatorSupervisorFeedbackScreen> {
  List<Evaluation> _evaluations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEvaluations();
  }

  Future<void> _loadEvaluations() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final evaluations = await EvaluationService.getEvaluations();
      setState(() {
        _evaluations = evaluations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Feedback'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvaluations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEvaluations,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _evaluations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.feedback_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No evaluations found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadEvaluations,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _evaluations.length,
                        itemBuilder: (context, index) {
                          final eval = _evaluations[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.deepPurple.withOpacity(0.1),
                                child: const Icon(Icons.assessment,
                                    color: Colors.deepPurple),
                              ),
                              title: Text(
                                eval.studentName ?? 'Unknown Student',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Supervisor: ${eval.supervisorName ?? 'N/A'}'),
                                  if (eval.totalScore != null)
                                    Text(
                                      'Score: ${eval.totalScore!.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        color: _getScoreColor(eval.totalScore!),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (eval.dateEvaluated != null)
                                        _buildInfoRow(
                                          'Date Evaluated',
                                          DateFormat('MMM d, yyyy')
                                              .format(eval.dateEvaluated!),
                                        ),
                                      if (eval.status != null)
                                        _buildInfoRow('Status', eval.status!),
                                      if (eval.evaluationPeriodStart != null &&
                                          eval.evaluationPeriodEnd != null)
                                        _buildInfoRow(
                                          'Period',
                                          '${DateFormat('MMM d, yyyy').format(eval.evaluationPeriodStart!)} - ${DateFormat('MMM d, yyyy').format(eval.evaluationPeriodEnd!)}',
                                        ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Evaluation Criteria:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...eval.criteria.entries.map((entry) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8, left: 16),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(entry.key),
                                                ),
                                                Text(
                                                  entry.value.toString(),
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          )),
                                      if (eval.feedback != null &&
                                          eval.feedback!.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Feedback:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(eval.feedback!),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.orange;
    return Colors.red;
  }
}

