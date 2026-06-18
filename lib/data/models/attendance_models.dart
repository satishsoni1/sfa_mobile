class AttendanceApiResponse {
  final bool success;
  final String fromDate;
  final String toDate;
  final List<AttendanceEmployeeData> records;

  const AttendanceApiResponse({
    required this.success,
    required this.fromDate,
    required this.toDate,
    required this.records,
  });

  factory AttendanceApiResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawRecords = json['data'] as List<dynamic>? ?? const [];

    return AttendanceApiResponse(
      success: json['success'] == true,
      fromDate: (json['from_date'] ?? '').toString(),
      toDate: (json['to_date'] ?? '').toString(),
      records: rawRecords
          .whereType<Map<String, dynamic>>()
          .map(AttendanceEmployeeData.fromJson)
          .toList(),
    );
  }
}

class AttendanceEmployeeData {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String designation;
  final String headQtr;
  final String division;
  final String zone;
  final String state;
  final List<AttendanceDayStatus> attendance;
  final Map<String, int> summary;

  const AttendanceEmployeeData({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.designation,
    required this.headQtr,
    required this.division,
    required this.zone,
    required this.state,
    required this.attendance,
    required this.summary,
  });

  factory AttendanceEmployeeData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawAttendance =
        json['attendance'] as List<dynamic>? ?? const [];
    final Map<String, dynamic> rawSummary =
        json['summary'] as Map<String, dynamic>? ?? const {};

    return AttendanceEmployeeData(
      employeeId: _toInt(json['employee_id']),
      employeeCode: (json['employee_code'] ?? json['emp_code'] ?? json['code'] ?? '').toString(),
      employeeName: (json['employee_name'] ?? '').toString(),
      designation: (json['designation'] ?? '').toString(),
      headQtr: (json['hq'] ?? json['head_qtr'] ?? json['head_quarter'] ?? '').toString(),
      division: (json['division'] ?? '').toString(),
      zone: (json['zone'] ?? json['zone_name'] ?? '').toString(),
      state: (json['state'] ?? json['state_name'] ?? '').toString(),
      attendance: rawAttendance
          .whereType<Map<String, dynamic>>()
          .map(AttendanceDayStatus.fromJson)
          .toList(),
      // Backend-controlled summary keys are preserved dynamically.
      summary: rawSummary.map((key, value) => MapEntry(key, _toInt(value))),
    );
  }

  AttendanceDayStatus? statusForDate(String date) {
    try {
      return attendance.firstWhere((entry) => entry.date == date);
    } catch (_) {
      return null;
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AttendanceDayStatus {
  final String date;
  final String status;

  const AttendanceDayStatus({required this.date, required this.status});

  factory AttendanceDayStatus.fromJson(Map<String, dynamic> json) {
    return AttendanceDayStatus(
      date: (json['date'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class AttendanceDetailResponse {
  final bool success;
  final String date;
  final Map<String, dynamic> employee;
  final Map<String, dynamic> summary;
  final Map<String, List<Map<String, dynamic>>> details;

  const AttendanceDetailResponse({
    required this.success,
    required this.date,
    required this.employee,
    required this.summary,
    required this.details,
  });

  factory AttendanceDetailResponse.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'] as Map<String, dynamic>? ?? {};

    return AttendanceDetailResponse(
      success: json['success'] == true,
      date: (json['date'] ?? '').toString(),
      employee: _toStringKeyMap(json['employee']),
      summary: _toStringKeyMap(json['summary']),
      // Every detail section stays backend-driven: nfw, visits, dcr, chemist_reports, or any future key.
      details: rawDetails.map((key, value) {
        final rows = <Map<String, dynamic>>[];
        if (value is List) {
          for (final item in value) {
            if (item is Map) {
              rows.add(item.map((k, v) => MapEntry(k.toString(), v)));
            }
          }
        }
        return MapEntry(key, rows);
      }),
    );
  }
}

Map<String, dynamic> _toStringKeyMap(dynamic value) {
  if (value is! Map) return {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}
