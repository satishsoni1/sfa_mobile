class TourPlan {
  final int id;
  final DateTime date;
  final List<int> doctorIds;
  final String? status; // Values: 'Draft', 'Pending', 'Approved', 'Rejected'

  TourPlan({
    required this.id,
    required this.date,
    required this.doctorIds,
    this.status,
  });

  // Factory constructor to create a TourPlan from JSON (API response)
  factory TourPlan.fromJson(Map<String, dynamic> json) {
    return TourPlan(
      id: json['id'] ?? 0, // Handle missing ID if needed
      // FIX: Check for 'plan_date' first, then 'date'
      date: DateTime.parse(json['plan_date'] ?? json['date']),
      doctorIds: json['doctor_ids'] != null
          ? List<int>.from(
              json['doctor_ids'].map((x) => int.parse(x.toString())),
            )
          : [],
      status: json['status'] ?? 'Draft',
    );
  }

  // Convert TourPlan to JSON (for sending to API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String().split('T')[0], // Format: YYYY-MM-DD
      'doctor_ids': doctorIds,
      'status': status,
    };
  }
}
