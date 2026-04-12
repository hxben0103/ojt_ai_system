class Competency {
  final int competencyId;
  final String title;
  final int pointValue;

  Competency({
    required this.competencyId,
    required this.title,
    required this.pointValue,
  });

  factory Competency.fromJson(Map<String, dynamic> json) {
    return Competency(
      competencyId: json['competencyId'] as int,
      title: json['title'] as String,
      pointValue: json['pointValue'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'competencyId': competencyId,
      'title': title,
      'pointValue': pointValue,
    };
  }
}
