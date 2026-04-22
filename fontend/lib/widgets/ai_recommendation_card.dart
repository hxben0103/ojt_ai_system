import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AIRecommendationCard extends StatelessWidget {
  final String riskLevel;
  final String trendStatus;
  final String trendReason;
  final String recommendation;
  final String? gemmaExplanation;
  final bool isLoading;

  const AIRecommendationCard({
    Key? key,
    required this.riskLevel,
    required this.trendStatus,
    required this.trendReason,
    required this.recommendation,
    this.gemmaExplanation,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 150,
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
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final Color statusColor = _getStatusColor();
    final IconData statusIcon = _getStatusIcon();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.05),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: statusColor.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AI Learning Coach',
                    style: AppTheme.heading3.copyWith(fontSize: 16, color: statusColor),
                  ),
                  const Spacer(),
                  _buildRiskBadge(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              recommendation,
                              style: AppTheme.bodyMedium.copyWith(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (gemmaExplanation != null && gemmaExplanation!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade100.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology_outlined, size: 14, color: Colors.purple.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Detailed Analysis',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            gemmaExplanation!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade900,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              trendStatus == 'improving' ? Icons.trending_up : 
                              trendStatus == 'declining' ? Icons.trending_down : Icons.trending_flat,
                              size: 16,
                              color: _getTrendColor(),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Recent Trend: ${trendStatus.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getTrendColor(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trendReason,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRiskBadge() {
    final color = _getStatusColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${_getFriendlyRisk(riskLevel).toUpperCase()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return Colors.red.shade600;
      case 'MEDIUM':
        return Colors.orange.shade700;
      case 'LOW':
        return Colors.green.shade600;
      default:
        return AppTheme.studentPrimary;
    }
  }

  IconData _getStatusIcon() {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return Icons.warning_rounded;
      case 'MEDIUM':
        return Icons.info_outline_rounded;
      case 'LOW':
        return Icons.emoji_events_rounded;
      default:
        return Icons.lightbulb_rounded;
    }
  }

  Color _getTrendColor() {
    switch (trendStatus.toLowerCase()) {
      case 'improving':
        return Colors.green.shade700;
      case 'declining':
        return Colors.red.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  String _getGreeting() {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return 'We need to talk...';
      case 'MEDIUM':
        return 'Keep pushing!';
      case 'LOW':
        return 'Excellent work!';
      default:
        return 'Hello there!';
    }
  }

  String _getFriendlyRisk(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH': return 'Needs Attention';
      case 'MEDIUM': return 'Fair Standing';
      case 'LOW': return 'Good Standing';
      default: return 'Pending Review';
    }
  }
}

