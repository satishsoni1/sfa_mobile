class CmeProgram {
  final int? id;
  final String cmeDate;
  final String topicName;
  final CmeSpeaker speaker;
  final List<CmeAttendee> attendees;
  final List<CmeManualDoctor> manualDoctors;
  final CmeJointWork? jointWork;
  final CmeCostBreakdown? costBreakdown;
  final int extraAttendeesCount;
  final String? extraAttendeesNotes;
  final String? remarks;
  final String? createdAt;
  final String? status;

  CmeProgram({
    this.id,
    required this.cmeDate,
    required this.topicName,
    required this.speaker,
    required this.attendees,
    this.manualDoctors = const [],
    this.jointWork,
    this.costBreakdown,
    this.extraAttendeesCount = 0,
    this.extraAttendeesNotes,
    this.remarks,
    this.createdAt,
    this.status,
  });

  factory CmeProgram.fromJson(Map<String, dynamic> json) {
    // Attendees parsing
    List<CmeAttendee> attendeesList = [];
    if (json['attendees'] != null && json['attendees'] is List) {
      attendeesList = (json['attendees'] as List)
          .map((item) => CmeAttendee.fromJson(item is Map<String, dynamic> ? item : {}))
          .toList();
    }

    // Manual doctors parsing
    List<CmeManualDoctor> manualDocsList = [];
    if (json['manual_doctors'] != null && json['manual_doctors'] is List) {
      manualDocsList = (json['manual_doctors'] as List)
          .map((item) => CmeManualDoctor.fromJson(item is Map<String, dynamic> ? item : {}))
          .toList();
    }

    // Speaker parsing (support object or flat keys)
    CmeSpeaker parsedSpeaker;
    if (json['speaker'] != null && json['speaker'] is Map<String, dynamic>) {
      parsedSpeaker = CmeSpeaker.fromJson(json['speaker']);
    } else {
      parsedSpeaker = CmeSpeaker(
        doctorId: json['speaker_id'] != null ? int.tryParse(json['speaker_id'].toString()) : null,
        doctorName: json['speaker_name']?.toString() ?? 'Unknown Speaker',
        speciality: json['speaker_speciality']?.toString(),
        isManual: json['speaker_is_manual'] == true || json['speaker_is_manual'] == 1,
      );
    }

    // Joint work parsing
    CmeJointWork? parsedJointWork;
    if (json['joint_work'] != null && json['joint_work'] is Map<String, dynamic>) {
      parsedJointWork = CmeJointWork.fromJson(json['joint_work']);
    } else if (json['joint_work_name'] != null && json['joint_work_name'].toString().isNotEmpty) {
      parsedJointWork = CmeJointWork(
        employeeId: json['joint_work_id'] != null ? int.tryParse(json['joint_work_id'].toString()) : null,
        employeeName: json['joint_work_name'].toString(),
        isJointWork: true,
      );
    }

    // Cost breakdown parsing
    CmeCostBreakdown? parsedCost;
    if (json['cost_breakdown'] != null && json['cost_breakdown'] is Map<String, dynamic>) {
      parsedCost = CmeCostBreakdown.fromJson(json['cost_breakdown']);
    } else if (json['total_cost'] != null) {
      final total = double.tryParse(json['total_cost'].toString()) ?? 0.0;
      parsedCost = CmeCostBreakdown(
        hasCost: total > 0,
        totalCost: total,
      );
    }

    // Extra attendees parsing
    int extraCount = 0;
    String? extraNotes;
    if (json['extra_attendees'] != null && json['extra_attendees'] is Map<String, dynamic>) {
      extraCount = int.tryParse(json['extra_attendees']['count']?.toString() ?? '0') ?? 0;
      extraNotes = json['extra_attendees']['notes']?.toString();
    } else {
      extraCount = int.tryParse(json['extra_attendees_count']?.toString() ?? '0') ?? 0;
      extraNotes = json['extra_attendees_notes']?.toString();
    }

    return CmeProgram(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      cmeDate: json['cme_date']?.toString() ?? json['date']?.toString() ?? '',
      topicName: json['topic_name']?.toString() ?? json['topic']?.toString() ?? '',
      speaker: parsedSpeaker,
      attendees: attendeesList,
      manualDoctors: manualDocsList,
      jointWork: parsedJointWork,
      costBreakdown: parsedCost,
      extraAttendeesCount: extraCount,
      extraAttendeesNotes: extraNotes,
      remarks: json['remarks']?.toString(),
      createdAt: json['created_at']?.toString(),
      status: json['status']?.toString() ?? 'Submitted',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'cme_date': cmeDate,
      'topic_name': topicName,
      'speaker': speaker.toJson(),
      'attendees': attendees.map((a) => a.toJson()).toList(),
      if (manualDoctors.isNotEmpty)
        'manual_doctors': manualDoctors.map((m) => m.toJson()).toList(),
      if (jointWork != null && jointWork!.isJointWork)
        'joint_work': jointWork!.toJson(),
      if (costBreakdown != null && costBreakdown!.hasCost)
        'cost_breakdown': costBreakdown!.toJson(),
      'extra_attendees': {
        'count': extraAttendeesCount,
        'notes': extraAttendeesNotes ?? '',
      },
      if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
    };
  }
}

class CmeSpeaker {
  final int? doctorId;
  final String doctorName;
  final String? speciality;
  final bool isManual;

  CmeSpeaker({
    this.doctorId,
    required this.doctorName,
    this.speciality,
    this.isManual = false,
  });

  factory CmeSpeaker.fromJson(Map<String, dynamic> json) {
    return CmeSpeaker(
      doctorId: json['doctor_id'] != null ? int.tryParse(json['doctor_id'].toString()) : null,
      doctorName: json['doctor_name']?.toString() ?? json['name']?.toString() ?? 'Unknown Speaker',
      speciality: json['speciality']?.toString(),
      isManual: json['is_manual'] == true || json['is_manual'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (doctorId != null) 'doctor_id': doctorId,
      'doctor_name': doctorName,
      if (speciality != null) 'speciality': speciality,
      'is_manual': isManual,
    };
  }
}

class CmeAttendee {
  final int? doctorId;
  final String doctorName;
  final String? speciality;
  final String? area;
  final bool isManual;

  CmeAttendee({
    this.doctorId,
    required this.doctorName,
    this.speciality,
    this.area,
    this.isManual = false,
  });

  factory CmeAttendee.fromJson(Map<String, dynamic> json) {
    return CmeAttendee(
      doctorId: json['doctor_id'] != null ? int.tryParse(json['doctor_id'].toString()) : null,
      doctorName: json['doctor_name']?.toString() ?? json['name']?.toString() ?? '',
      speciality: json['speciality']?.toString(),
      area: json['area']?.toString(),
      isManual: json['is_manual'] == true || json['is_manual'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (doctorId != null) 'doctor_id': doctorId,
      'doctor_name': doctorName,
      if (speciality != null) 'speciality': speciality,
      if (area != null) 'area': area,
      'is_manual': isManual,
    };
  }
}

class CmeManualDoctor {
  final String doctorName;
  final String? speciality;
  final String? mobileNo;
  final String? area;
  final String? hospitalName;

  CmeManualDoctor({
    required this.doctorName,
    this.speciality,
    this.mobileNo,
    this.area,
    this.hospitalName,
  });

  factory CmeManualDoctor.fromJson(Map<String, dynamic> json) {
    return CmeManualDoctor(
      doctorName: json['doctor_name']?.toString() ?? json['name']?.toString() ?? '',
      speciality: json['speciality']?.toString(),
      mobileNo: json['mobile_no']?.toString(),
      area: json['area']?.toString(),
      hospitalName: json['hospital_name']?.toString() ?? json['clinic_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctor_name': doctorName,
      if (speciality != null && speciality!.isNotEmpty) 'speciality': speciality,
      if (mobileNo != null && mobileNo!.isNotEmpty) 'mobile_no': mobileNo,
      if (area != null && area!.isNotEmpty) 'area': area,
      if (hospitalName != null && hospitalName!.isNotEmpty) 'hospital_name': hospitalName,
    };
  }
}

class CmeJointWork {
  final int? employeeId;
  final String employeeName;
  final bool isJointWork;

  CmeJointWork({
    this.employeeId,
    required this.employeeName,
    this.isJointWork = true,
  });

  factory CmeJointWork.fromJson(Map<String, dynamic> json) {
    return CmeJointWork(
      employeeId: json['employee_id'] != null
          ? int.tryParse(json['employee_id'].toString())
          : (json['id'] != null ? int.tryParse(json['id'].toString()) : null),
      employeeName: json['employee_name']?.toString() ?? json['name']?.toString() ?? '',
      isJointWork: json['is_joint_work'] == true || json['is_joint_work'] == 1 || json['is_joint_work'] == null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (employeeId != null) 'employee_id': employeeId,
      'employee_name': employeeName,
      'is_joint_work': isJointWork,
    };
  }
}

class CmeCostItem {
  final String type;
  final double amount;

  CmeCostItem({
    required this.type,
    required this.amount,
  });

  factory CmeCostItem.fromJson(Map<String, dynamic> json) {
    return CmeCostItem(
      type: json['type']?.toString() ??
          json['description']?.toString() ??
          json['name']?.toString() ??
          'Cost',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
    };
  }
}

class CmeCostBreakdown {
  final bool hasCost;
  final List<CmeCostItem> items;
  final double venueAmount;
  final double cateringAmount;
  final double audiovisualAmount;
  final double honorariumAmount;
  final double miscellaneousAmount;
  final double totalCost;

  CmeCostBreakdown({
    this.hasCost = false,
    this.items = const [],
    this.venueAmount = 0.0,
    this.cateringAmount = 0.0,
    this.audiovisualAmount = 0.0,
    this.honorariumAmount = 0.0,
    this.miscellaneousAmount = 0.0,
    double? totalCost,
  }) : totalCost = totalCost ??
            (items.isNotEmpty
                ? items.fold<double>(0.0, (sum, i) => sum + i.amount)
                : (venueAmount +
                    cateringAmount +
                    audiovisualAmount +
                    honorariumAmount +
                    miscellaneousAmount));

  factory CmeCostBreakdown.fromJson(Map<String, dynamic> json) {
    List<CmeCostItem> itemsList = [];
    if (json['items'] != null && json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((i) => CmeCostItem.fromJson(Map<String, dynamic>.from(i is Map ? i : {})))
          .toList();
    }

    final venue = double.tryParse(json['venue_amount']?.toString() ?? '0') ?? 0.0;
    final catering = double.tryParse(json['catering_amount']?.toString() ?? '0') ?? 0.0;
    final av = double.tryParse(json['audiovisual_amount']?.toString() ?? '0') ?? 0.0;
    final honorarium = double.tryParse(json['honorarium_amount']?.toString() ?? '0') ?? 0.0;
    final misc = double.tryParse(json['miscellaneous_amount']?.toString() ?? '0') ?? 0.0;

    double computedTotal = 0.0;
    if (itemsList.isNotEmpty) {
      computedTotal = itemsList.fold<double>(0.0, (sum, i) => sum + i.amount);
    } else {
      computedTotal = venue + catering + av + honorarium + misc;
    }

    final total = json['total_cost'] != null
        ? (double.tryParse(json['total_cost'].toString()) ?? computedTotal)
        : computedTotal;

    return CmeCostBreakdown(
      hasCost: json['has_cost'] == true || total > 0,
      items: itemsList,
      venueAmount: venue,
      cateringAmount: catering,
      audiovisualAmount: av,
      honorariumAmount: honorarium,
      miscellaneousAmount: misc,
      totalCost: total,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_cost': hasCost,
      if (items.isNotEmpty) 'items': items.map((i) => i.toJson()).toList(),
      'total_cost': totalCost,
      if (venueAmount > 0) 'venue_amount': venueAmount,
      if (cateringAmount > 0) 'catering_amount': cateringAmount,
      if (audiovisualAmount > 0) 'audiovisual_amount': audiovisualAmount,
      if (honorariumAmount > 0) 'honorarium_amount': honorariumAmount,
      if (miscellaneousAmount > 0) 'miscellaneous_amount': miscellaneousAmount,
    };
  }
}
