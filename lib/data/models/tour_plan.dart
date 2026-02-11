import 'doctor.dart'; // Ensure this path is correct

class TourPlan {
  final int id;
  final DateTime date;
  final List<int> doctorIds;
  final String? status;
  final List<Doctor> doctors;

  TourPlan({
    required this.id,
    required this.date,
    required this.doctorIds,
    this.status,
    this.doctors = const [],
  });

  factory TourPlan.fromJson(Map<String, dynamic> json) {
    // 1. Parse full doctor objects
    var docList = json['doctors'] as List? ?? [];
    List<Doctor> parsedDoctors = docList.map((d) => Doctor.fromJson(d)).toList();

    // 2. Parse IDs safely
    List<int> parsedIds = [];
    if (json['doctor_ids'] != null) {
      parsedIds = List<int>.from(json['doctor_ids']);
    } else {
      // FIX 2: Handle potentially nullable IDs by defaulting to 0
      parsedIds = parsedDoctors
          .map((d) => d.id ?? 0) // Explicitly handle nulls
          .toList();
    }

    return TourPlan(
      id: json['id'] ?? 0,
      date: DateTime.parse(json['plan_date']),
      doctorIds: parsedIds,
      status: json['status'],
      doctors: parsedDoctors,
    );
  }

  // FIX 1: Add the missing toJson method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_date': date.toIso8601String(), // Or format as 'yyyy-MM-dd' if backend requires
      'doctor_ids': doctorIds,
      'status': status,
      // Ensure Doctor model also has toJson, otherwise remove this line
      'doctors': doctors.map((d) => d.toJson()).toList(), 
    };
  }
}