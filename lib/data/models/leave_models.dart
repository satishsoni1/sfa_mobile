class LeaveBalance {
  final int leaveHeadId;
  final String leaveCode; // e.g., 'CL', 'PL'
  final String description;
  final double availableDays;

  LeaveBalance({
    required this.leaveHeadId,
    required this.leaveCode,
    required this.description,
    required this.availableDays,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      leaveHeadId: json['leave_head_id'],
      leaveCode: json['code'] ?? '',
      description: json['description'] ?? '',
      availableDays: double.tryParse(json['available_days'].toString()) ?? 0.0,
    );
  }
}

class LeaveDetail {
  final String leaveHead;
  final double requiredDays;

  LeaveDetail({required this.leaveHead, required this.requiredDays});

  factory LeaveDetail.fromJson(Map<String, dynamic> json) {
    return LeaveDetail(
      leaveHead: json['leave_head'],
      requiredDays: double.tryParse(json['required_days'].toString()) ?? 0.0,
    );
  }
}