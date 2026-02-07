import 'package:intl/intl.dart';

class TourPlan {
  final DateTime date;
  final List<int> doctorIds;
  final String status; // e.g., "Submitted", "Draft"

  TourPlan({
    required this.date,
    required this.doctorIds,
    this.status = 'Submitted',
  });

  // --- 1. FROM JSON (API -> App) ---
  factory TourPlan.fromJson(Map<String, dynamic> json) {
    return TourPlan(
      // Parse date string (e.g., "2023-10-25") to DateTime
      date: DateTime.parse(json['plan_date']),

      // Safely convert JSON array to List<int>
      doctorIds: json['doctor_ids'] != null
          ? List<int>.from(json['doctor_ids'])
          : [],

      status: json['status'] ?? 'Submitted',
    );
  }

  // --- 2. TO JSON (App -> API) ---
  Map<String, dynamic> toJson() {
    return {
      // Format DateTime back to string "yyyy-MM-dd" for Laravel
      'plan_date': DateFormat('yyyy-MM-dd').format(date),
      'doctor_ids': doctorIds,
      'status': status,
    };
  }
}
