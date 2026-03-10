import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class ExplainableAiCard extends StatelessWidget {
  final Map<dynamic, dynamic> prediction;
  final bool isExpanded;

  const ExplainableAiCard({
    super.key,
    required this.prediction,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (prediction['ai_prediction'] == null) return const SizedBox.shrink();
    
    final ai = Map<String, dynamic>.from(prediction['ai_prediction'] as Map);
    
    // Early-stage detection: show informational card instead of incomplete ML data
    final isEarlyStage = prediction['early_stage'] == true || ai['early_stage'] == true;
    if (isEarlyStage) {
      final summary = prediction['summary'] as String?
          ?? ai['summary'] as String?
          ?? 'Student just started OJT. Log tasks and attendance to unlock predictions.';
      return _buildEarlyStageCard(context, summary);
    }
    
    final ml = ai['ml_prediction'] != null 
        ? Map<String, dynamic>.from(ai['ml_prediction'] as Map) 
        : <String, dynamic>{};
    final grading = ai['grading'] != null 
        ? Map<String, dynamic>.from(ai['grading'] as Map)
        : <String, dynamic>{};
    final integrity = ai['integrity'] != null 
        ? Map<String, dynamic>.from(ai['integrity'] as Map)
        : <String, dynamic>{};
    final summary = ai['summary'] as String? ?? 'No summary available.';
    
    final riskLevel = ml['risk_level'] as String? ?? 'UNKNOWN';
    final probability = (ml['probability'] as num?)?.toDouble() ?? 0.0;
    final score = (ml['score'] as num?)?.toDouble() ?? 0.0;
    final keyFactors = (ml['key_factors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Risk & Confidence
          _buildHeader(context, riskLevel, probability, score),
          
          if (isExpanded) ...[
            const Divider(height: 1),
            // Explainable Factors
            _buildFactorsSection(context, keyFactors),
            
            const Divider(height: 1),
            // Grading Breakdown (The 20/20/20/40 logic)
            _buildGradingSection(context, grading),
            
            const Divider(height: 1),
            // Integrity Insights
            _buildIntegritySection(context, integrity),
            
            const Divider(height: 1),
            // Gemma AI Narrative
            _buildNarrativeSection(context, summary),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String risk, double prob, double score) {
    Color riskColor = _getRiskColor(risk);
    IconData riskIcon = _getRiskIcon(risk);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(riskIcon, color: riskColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI Risk: $risk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${(prob * 100).toStringAsFixed(0)}% confidence)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ML Performance Score: ${score.toStringAsFixed(1)}/100',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (!isExpanded)
            Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildFactorsSection(BuildContext context, List<String> factors) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'Leading Decision Factors',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...factors.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    f,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          )),
          if (factors.isEmpty)
            Text(
              'Insufficient data for detailed factor analysis.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _buildGradingSection(BuildContext context, Map<String, dynamic> grading) {
    final components = grading['components'] != null 
        ? Map<String, dynamic>.from(grading['components'] as Map)
        : <String, dynamic>{};
    final forecasted = (grading['forecasted_grade'] as num?)?.toDouble() ?? 0.0;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment_outlined, size: 18, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'OJT Grading Forecast (20/20/20/40 Weights)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Text(
                'Est. $forecasted',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGradeItem('Weekly Progress (WPR)', components['weekly_progress'], 0.20),
          const SizedBox(height: 8),
          _buildGradeItem('Narrative Report (NR)', components['narrative_report'], 0.20),
          const SizedBox(height: 8),
          _buildGradeItem('Coordinator Eval (CE)', components['coordinator_eval'], 0.20),
          const SizedBox(height: 8),
          _buildGradeItem('Supervisor Eval (SE)', components['supervisor_eval'], 0.40),
        ],
      ),
    );
  }

  Widget _buildGradeItem(String label, dynamic dataRaw, double totalWeight) {
    if (dataRaw == null) return const SizedBox.shrink();
    final data = Map<String, dynamic>.from(dataRaw as Map);
    
    final score = (data['score'] as num?)?.toDouble() ?? 0.0;
    final available = data['available'] as bool? ?? false;
    final weightLabel = data['weight'] as String? ?? '${(totalWeight * 100).toInt()}%';
    
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                available ? Colors.purple.shade300 : Colors.grey.shade300,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 45,
          child: Text(
            available ? score.toStringAsFixed(1) : 'PEND',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.bold,
              color: available ? Colors.grey.shade800 : Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(weightLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildIntegritySection(BuildContext context, Map<String, dynamic> integrity) {
    final score = (integrity['integrity_score'] as num?)?.toDouble() ?? 100.0;
    final flags = (integrity['flags_caught'] as List<dynamic>?)?.length ?? 0;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 18, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          const Text(
            'Integrity Score:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            score.toInt().toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: score < 70 ? Colors.red : Colors.teal.shade700,
            ),
          ),
          const Spacer(),
          if (flags > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                '$flags FLAGS',
                style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNarrativeSection(BuildContext context, String summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              Text(
                'Gemma AI Narrative',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.purple.shade900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarlyStageCard(BuildContext context, String summary) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch_outlined, size: 18, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                'Early Stage OJT',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'More Data Needed',
                  style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, size: 14, color: Colors.blue.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Full ML prediction unlocks after logging 5+ tasks and 10+ OJT hours.',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH': return Colors.red;
      case 'MEDIUM': return Colors.orange;
      case 'LOW': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getRiskIcon(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH': return Icons.warning_amber_rounded;
      case 'MEDIUM': return Icons.info_outline;
      case 'LOW': return Icons.check_circle_outline;
      default: return Icons.help_outline;
    }
  }
}
