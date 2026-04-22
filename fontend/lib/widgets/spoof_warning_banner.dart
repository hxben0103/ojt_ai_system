import 'package:flutter/material.dart';

/// Banner shown when location is flagged as suspicious (e.g. mock or low trust).
class SpoofWarningBanner extends StatelessWidget {
  final List<String> reasons;
  final int trustScore;

  const SpoofWarningBanner({
    super.key,
    required this.reasons,
    this.trustScore = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          left: BorderSide(color: Colors.orange, width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Location flagged',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                    fontSize: 13,
                  ),
                ),
                if (trustScore > 0 && trustScore < 100)
                  Text(
                    'Trust score: $trustScore/100',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ...reasons.map(
                  (r) => Text(
                    '• $r',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

