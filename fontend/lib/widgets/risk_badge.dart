import 'package:flutter/material.dart';

/// Reusable risk level badge widget for displaying AI risk levels
class RiskBadge extends StatelessWidget {
  final String riskLevel;
  final bool compact;

  const RiskBadge({
    super.key,
    required this.riskLevel,
    this.compact = false,
  });

  Color get _backgroundColor {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return Colors.red.shade100;
      case 'MEDIUM':
        return Colors.orange.shade100;
      case 'LOW':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  String get _friendlyText {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return 'Needs Attention';
      case 'MEDIUM':
        return 'Fair Standing';
      case 'LOW':
        return 'Good Standing';
      default:
        return 'Pending Review';
    }
  }

  Color get _textColor {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return Colors.red.shade900;
      case 'MEDIUM':
        return Colors.orange.shade900;
      case 'LOW':
        return Colors.green.shade900;
      default:
        return Colors.grey.shade900;
    }
  }

  IconData get _icon {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return Icons.warning;
      case 'MEDIUM':
        return Icons.info;
      case 'LOW':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 14, color: _textColor),
            const SizedBox(width: 4),
            Text(
              _friendlyText,
              style: TextStyle(
                color: _textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _textColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 18, color: _textColor),
          const SizedBox(width: 8),
          Text(
            _friendlyText,
            style: TextStyle(
              color: _textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

