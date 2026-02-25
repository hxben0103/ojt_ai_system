/// Result of location trust evaluation (0-100 score, suspicious flag, reasons).
class TrustResult {
  /// Score 0-100; lower = more suspicious.
  final int score;
  final bool isSuspicious;
  final List<String> reasons;

  TrustResult({
    required this.score,
    required this.isSuspicious,
    this.reasons = const [],
  });

  /// Default "trusted" result when no checks run (e.g. web).
  factory TrustResult.trusted() {
    return TrustResult(score: 100, isSuspicious: false, reasons: []);
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'is_suspicious': isSuspicious,
      'reasons': reasons,
    };
  }
}
