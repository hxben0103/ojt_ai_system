import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/attendance.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';

class DailyRhythmChart extends StatelessWidget {
  final List<Attendance> records;
  final double startHour;
  final double endHour;
  final double interval; // in hours, e.g., 0.5 for 30 mins

  const DailyRhythmChart({
    super.key,
    required this.records,
    this.startHour = 7.0, // 7 AM
    this.endHour = 20.0, // 8 PM
    this.interval = 0.5, // 30-minute blocks
  });

  @override
  Widget build(BuildContext context) {
    // Sort records by date descending (latest first)
    final sortedRecords = List<Attendance>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Limit to last 14 days for clarity
    final displayRecords = sortedRecords.take(14).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(),
        const SizedBox(height: 20),
        _buildTimeLabels(),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayRecords.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final record = displayRecords[index];
            return _buildDayRow(context, record);
          },
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text("Less", style: GoogleFonts.outfit(fontSize: 10, color: Colors.black45)),
        const SizedBox(width: 4),
        _buildLegendSquare(Colors.grey.shade100),
        _buildLegendSquare(AppTheme.coordinatorPrimary.withOpacity(0.3)),
        _buildLegendSquare(AppTheme.coordinatorPrimary.withOpacity(0.6)),
        _buildLegendSquare(AppTheme.coordinatorPrimary),
        const SizedBox(width: 4),
        Text("More", style: GoogleFonts.outfit(fontSize: 10, color: Colors.black45)),
      ],
    );
  }

  Widget _buildLegendSquare(Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: color == Colors.grey.shade100 
            ? Border.all(color: Colors.grey.shade300, width: 0.5) 
            : null,
      ),
    );
  }

  Widget _buildTimeLabels() {
    return Padding(
      padding: const EdgeInsets.only(left: 60), // Space for date labels
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTimeLabel("7A"),
          _buildTimeLabel("10A"),
          _buildTimeLabel("1P"),
          _buildTimeLabel("4P"),
          _buildTimeLabel("8P"),
        ],
      ),
    );
  }

  Widget _buildTimeLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 10,
        color: Colors.black38,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDayRow(BuildContext context, Attendance record) {
    final int blocksCount = ((endHour - startHour) / interval).ceil();
    
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            DateFormat('MMM dd').format(record.date),
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(blocksCount, (index) {
              final currentBlockHour = startHour + (index * interval);
              final status = _getBlockStatus(record, currentBlockHour);
              
              return Expanded(
                child: Container(
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(3),
                    border: status == _BlockStatus.inactive
                        ? Border.all(color: Colors.grey.shade200, width: 0.5)
                        : null,
                    boxShadow: status != _BlockStatus.inactive 
                      ? [
                          BoxShadow(
                            color: _getStatusColor(status).withOpacity(0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  _BlockStatus _getBlockStatus(Attendance record, double hour) {
    // Check if the hour falls within any active segment
    bool isMorning = _isTimeInRange(hour, record.morningIn, record.morningOut);
    bool isAfternoon = _isTimeInRange(hour, record.afternoonIn, record.afternoonOut);
    bool isOvertime = _isTimeInRange(hour, record.overtimeIn, record.overtimeOut);

    if (isOvertime) return _BlockStatus.overtime;
    if (isAfternoon) return _BlockStatus.afternoon;
    if (isMorning) return _BlockStatus.morning;
    return _BlockStatus.inactive;
  }

  bool _isTimeInRange(double hour, String? timeIn, String? timeOut) {
    if (timeIn == null || timeOut == null || timeIn == "-" || timeOut == "-") return false;
    final double inVal = _parseTimeToDouble(timeIn);
    final double outVal = _parseTimeToDouble(timeOut);
    // Return true if the block (spanning 'interval') overlaps with the range
    return hour >= (inVal - 0.25) && hour < outVal;
  }

  Color _getStatusColor(_BlockStatus status) {
    switch (status) {
      case _BlockStatus.morning:
        return AppTheme.coordinatorPrimary.withOpacity(0.4);
      case _BlockStatus.afternoon:
        return AppTheme.coordinatorPrimary.withOpacity(0.7);
      case _BlockStatus.overtime:
        return AppTheme.coordinatorPrimary;
      case _BlockStatus.inactive:
        return Colors.grey.shade100;
    }
  }

  double _parseTimeToDouble(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final double hours = double.parse(parts[0]);
      final double minutes = double.parse(parts[1]);
      return hours + (minutes / 60.0);
    } catch (e) {
      return 0.0;
    }
  }
}

enum _BlockStatus { inactive, morning, afternoon, overtime }

