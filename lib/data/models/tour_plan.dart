class TourPlan {
  final String? id;
  final DateTime date;
  final String area;
  final String objective;
  final bool isJointWork;
  final List<String>? jointWith; // List of IDs or Names

  TourPlan({
    this.id,
    required this.date,
    required this.area,
    required this.objective,
    this.isJointWork = false,
    this.jointWith,
  });

  // Factory: From JSON
  factory TourPlan.fromJson(Map<String, dynamic> json) {
    List<String>? partners;
    if (json['joint_with'] != null) {
      partners = List<String>.from(json['joint_with']);
    }

    return TourPlan(
      id: json['id'].toString(),
      date: DateTime.parse(json['date']),
      area: json['area'] ?? '',
      objective: json['objective'] ?? '',
      isJointWork: json['is_joint_work'] == 1 || json['is_joint_work'] == true,
      jointWith: partners,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0], // Send YYYY-MM-DD
      'area': area,
      'objective': objective,
      'is_joint_work': isJointWork,
      'joint_with': jointWith ?? [],
    };
  }
}