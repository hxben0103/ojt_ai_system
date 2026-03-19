import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../core/app_theme.dart';

/// A widget that shows a student's Forecasted Grade trend over time.
/// Fetches from GET /api/prediction/history/:studentId
class GradeTrendChart extends StatefulWidget {
  final int studentId;
  final String? studentName;

  const GradeTrendChart({
    super.key,
    required this.studentId,
    this.studentName,
  });

  @override
  State<GradeTrendChart> createState() => _GradeTrendChartState();
}

class _GradeTrendChartState extends State<GradeTrendChart> {
  List<_GradePoint> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response = await ApiService.get(
          '/prediction/history/${widget.studentId}');
      final list = response['history'] as List<dynamic>? ?? [];
      setState(() {
        _history = list
            .map((e) => _GradePoint.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null || _history.isEmpty) {
      return Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, size: 32, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'No grade history yet',
                style: AppTheme.bodySmall.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Row(
              children: [
                Icon(Icons.trending_up, size: 16,
                    color: AppTheme.coordinatorPrimary),
                const SizedBox(width: 6),
                Text(
                  'Grade Forecast Trend',
                  style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.coordinatorPrimary),
                ),
                const Spacer(),
                // Legend
                _LegendDot(color: Colors.green.shade600, label: 'Good (≥75)'),
                const SizedBox(width: 10),
                _LegendDot(color: Colors.orange, label: 'Risk (<75)'),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= _history.length) {
                          return const SizedBox.shrink();
                        }
                        final date = _history[idx].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('M/d').format(date),
                            style: TextStyle(
                                fontSize: 9, color: Colors.grey.shade500),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        AppTheme.coordinatorPrimary.withOpacity(0.9),
                    getTooltipItems: (spots) => spots.map((spot) {
                      final idx = spot.x.toInt();
                      final point =
                          idx < _history.length ? _history[idx] : null;
                      return LineTooltipItem(
                        point != null
                            ? '${DateFormat("MMM d").format(point.date)}\n${spot.y.toStringAsFixed(1)}'
                            : spot.y.toStringAsFixed(1),
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _history.asMap().entries.map((e) {
                      return FlSpot(
                          e.key.toDouble(), e.value.grade.toDouble());
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.coordinatorPrimary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) {
                        final color = spot.y >= 75
                            ? Colors.green.shade600
                            : Colors.orange;
                        return FlDotCirclePainter(
                          radius: 4,
                          color: color,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.coordinatorPrimary.withOpacity(0.15),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradePoint {
  final DateTime date;
  final double grade;
  final String riskLevel;

  _GradePoint({required this.date, required this.grade, required this.riskLevel});

  factory _GradePoint.fromJson(Map<String, dynamic> json) {
    DateTime date;
    try {
      date = DateTime.parse(json['date'].toString());
    } catch (_) {
      date = DateTime.now();
    }
    return _GradePoint(
      date: date,
      grade: (json['forecastedGrade'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['riskLevel'] as String? ?? 'UNKNOWN',
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}
