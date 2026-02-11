import 'doctor.dart'; // Ensure this path is correct

class TourPlan {
  final int id;
  final DateTime date;
  final List<int> doctorIds;
  final String? status;
  final String? remark; // Added: Manager's rejection remark
  final List<Doctor> doctors;
  final bool isActivity;
  final String? activityType;

  TourPlan({
    required this.id,
    required this.date,
    required this.doctorIds,
    this.status,
    this.remark,
    this.isActivity = false,
    this.activityType,
    this.doctors = const [],
  });

  factory TourPlan.fromJson(Map<String, dynamic> json) {
    // 1. Parse full doctor objects safely
    var docList = json['doctors'] as List? ?? [];
    List<Doctor> parsedDoctors = docList
        .map((d) => Doctor.fromJson(d))
        .toList();

    // 2. Parse IDs safely
    List<int> parsedIds = [];
    if (json['doctor_ids'] != null) {
      parsedIds = List<int>.from(json['doctor_ids']);
    } else {
      // Fallback: Extract IDs from the doctor objects if the direct ID list is missing
      parsedIds = parsedDoctors.map((d) => d.id ?? 0).toList();
    }

    return TourPlan(
      id: json['id'] ?? 0,
      // Handle date parsing safely (backend might send '2023-10-25' or ISO string)
      date: DateTime.parse(json['plan_date']),
      doctorIds: parsedIds,
      status: json['status'],
      remark: json['manager_remark'], // Map JSON field to class property
      isActivity: json['is_activity'] == 1 || json['is_activity'] == true,
      activityType: json['activity_type'],
      doctors: parsedDoctors,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // Format to simplified YYYY-MM-DD for backend consistency
      'plan_date': date.toIso8601String().split('T').first,
      'doctor_ids': doctorIds,
      'status': status,
      'is_activity': isActivity,
      'activity_type': activityType,
      'manager_remark': remark,
      // Only include if your backend expects full doctor objects in the payload
      'doctors': doctors.map((d) => d.toJson()).toList(),
    };
  }
}
