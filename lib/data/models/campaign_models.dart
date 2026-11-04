import 'dart:convert';

class DynamicField {
  final int id;
  final String fieldName;
  final String fieldLabel;
  final String fieldType;     
  final String uiComponent;   
  final String keyboardType;  
  final bool isRequired;
  final int displayOrder;

  DynamicField({
    required this.id,
    required this.fieldName,
    required this.fieldLabel,
    required this.fieldType,
    required this.uiComponent,
    required this.keyboardType,
    required this.isRequired,
    required this.displayOrder,
  });

  factory DynamicField.fromJson(Map<String, dynamic> json) {
    return DynamicField(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      fieldName: json['field_name']?.toString() ?? '',
      fieldLabel: json['field_label']?.toString() ?? '',
      fieldType: json['field_type']?.toString() ?? 'text',
      uiComponent: json['ui_component']?.toString() ?? 'text_input',
      keyboardType: json['keyboard_type']?.toString() ?? 'text',
      isRequired: json['is_required'] == true ||
          json['is_required'] == 1 ||
          json['is_required']?.toString().toLowerCase() == 'true',
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'field_name': fieldName,
      'field_label': fieldLabel,
      'field_type': fieldType,
      'ui_component': uiComponent,
      'keyboard_type': keyboardType,
      'is_required': isRequired,
      'display_order': displayOrder,
    };
  }
}

class CampaignFieldDefinition {
  final int campaignId;
  final String campaignName;
  final String? description;
  final String? startDate;
  final String? endDate;
  final String status;
  final String? schemaVersion;
  final String? schemaHash;
  final List<DynamicField> dynamicFields;

  CampaignFieldDefinition({
    required this.campaignId,
    required this.campaignName,
    this.description,
    this.startDate,
    this.endDate,
    this.status = 'active',
    this.schemaVersion,
    this.schemaHash,
    this.dynamicFields = const [],
  });

  factory CampaignFieldDefinition.fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['dynamic_fields'] as List? ?? [];
    return CampaignFieldDefinition(
      campaignId: int.tryParse(json['campaign_id']?.toString() ?? '') ?? 0,
      campaignName: json['campaign_name']?.toString() ?? '',
      description: (json['description'] ??
              json['campaign_type'] ??
              json['campaign_code'])
          ?.toString(),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      status: (json['status'] ?? json['campaign_type'] ?? 'active')?.toString() ??
          'active',
      schemaVersion: (json['campaign_schema_version'] ?? json['schema_version'])
          ?.toString(),
      schemaHash:
          (json['campaign_schema_hash'] ?? json['schema_hash'])?.toString(),
      dynamicFields: fieldsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => DynamicField.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_id': campaignId,
      'campaign_name': campaignName,
      'description': description,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'schema_version': schemaVersion,
      'schema_hash': schemaHash,
      'dynamic_fields': dynamicFields.map((f) => f.toJson()).toList(),
    };
  }
}


class CampaignDoctor {
  final String planDate;
  final String doctorId;
  final String doctorName;
  final int campaignId;
  final String campaignName;

  CampaignDoctor({
    required this.planDate,
    required this.doctorId,
    required this.doctorName,
    required this.campaignId,
    required this.campaignName,
  });

 
  static List<CampaignDoctor> fromMonthlyResponse(Map<String, dynamic> data) {
    final monthStatus = data['month_status']?.toString().toLowerCase();
    if (monthStatus != 'approved') return [];

    final plans = data['plans'];
    if (plans == null || plans is! Map<String, dynamic>) return [];

    final List<CampaignDoctor> result = [];

    for (final entry in plans.entries) {
      final date = entry.key; 
      final plan = entry.value;
      if (plan is! Map<String, dynamic>) continue;
      if (plan['has_campaign'] != true) continue;

      final campaigns = plan['campaigns'] as List? ?? [];
      for (final campaign in campaigns) {
        if (campaign is! Map<String, dynamic>) continue;
        final campaignId =
            int.tryParse(campaign['campaign_id']?.toString() ?? '') ?? 0;
        final campaignName = campaign['campaign_name']?.toString() ?? '';

        final doctors = campaign['doctors'] as List? ?? [];
        for (final doc in doctors) {
          if (doc is! Map<String, dynamic>) continue;
          result.add(CampaignDoctor(
            planDate: date,
            doctorId: doc['doctor_id']?.toString() ?? '',
            doctorName: doc['doctor_name']?.toString() ?? '',
            campaignId: campaignId,
            campaignName: campaignName,
          ));
        }
      }
    }
    return result;
  }
}
