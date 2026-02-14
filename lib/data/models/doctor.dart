class Doctor {
  final int? id;
  final String name;
  final String mobile;
  final String area;
  final String? pincode;
  final String specialization;
  final String? territoryType;
  final bool isKbl;
  final bool isFrd;
  final bool isOther;
  final bool isPlanned;
  final String? email;


  Doctor({
    this.id,
    required this.name,
    required this.mobile,
    required this.area,
    this.pincode,
    required this.specialization,
    this.territoryType,
    this.isKbl = false,
    this.isFrd = false,
    this.isOther = false,
    this.isPlanned = false,
    this.email,
  });

  // --- FIX: Match Keys exactly with API JSON ---
  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'],

      // API sends 'doctor_name', not 'name'
      name: _toTitleCase(json['doctor_name'] ?? 'Unknown Name'),

      // API sends 'mobile_no', not 'mobile'
      mobile: json['mobile_no']?.toString() ?? '',
      email: json['email']?.toString(),

      // API sends 'geo_name' (from join). Fallback to 'area' if null.
      area: _toTitleCase(json['area'] ?? ''),
      pincode: json['pincode']?.toString(),

      // API sends 'speciality', not 'specialization'
      specialization: _toTitleCase(json['speciality'] ?? ''),

      // API sends 'territory_type'
      territoryType: json['territory_type'],

      // Handle 1/0 or true/false
      isKbl: (json['is_kbl'] == 1 || json['is_kbl'] == true),
      isFrd: (json['is_frd'] == 1 || json['is_frd'] == true),
      isOther: (json['is_other'] == 1 || json['is_other'] == true),
      isPlanned: json['is_planned'] == true || json['is_planned'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor_name':
          name, // Changed to match API expectations if used for sending
      'mobile_no': mobile,
      'email': email,
      'area': area,
      'pincode': pincode,
      'speciality': specialization,
      'territory_type': territoryType,
      'is_kbl': isKbl ? 1 : 0,
      'is_frd': isFrd ? 1 : 0,
      'is_other': isOther ? 1 : 0,
    };
  }

  // Helper for Initials (UI)
  String get initials {
    if (name.isEmpty) return "?";
    List<String> parts = name.trim().split(" ");
    if (parts.length > 1) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return name[0].toUpperCase();
  }

  static String _toTitleCase(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
