class NewDoctor {
  final int? id;

  // Basic Info
  final String firstName;
  final String surname;
  final String doctorProfile; // H, T, HT
  final String? ageGroup; // <=35, 36-54, >=55

  // Professional
  final String specialtyQualification;
  final String specialtyPracticeType;
  final int? patientsPerDay;
  final List<String> daysAvailable; // Mon,Tue,Wed,Thu,Fri,Sat,Sun
  final int? routeId;
  final String? routeName; // town code from expense_rates_ta

  // Contact & Address
  final String mobile;
  final String whatsapp;
  final String email;
  final String address;
  final String town;
  final String city;
  final String pin;

  // Classification (mutually exclusive flags)
  final double? businessPotential; // in Lacs
  final bool isKbl;
  final bool isFrd;
  final bool isRemaining; // default true for new doctors
  final String? visitCategory; // CORE_3, FRD_2, KBL, REMAINING

  // Personalization
  final String? doctorRegNo;
  final String? dateOfBirth;
  final String? marriageAnniversary;
  final String? clinicOpeningDay;
  final String? interests;
  final String? prescriptionMode; // 'Online' / 'Offline'

  // Digital Presence (structured)
  final String? linkedin;
  final String? instagram;
  final String? website;
  final String? youtube;

  // Documents (server-returned URLs)
  final String? prescriptionPadImage;
  final String? visitingCardImage;
  final String? signBoardImage;

  // Psychographic
  final String? clinicalMindset;
  final bool earlyAdopter;
  final bool brandLoyalty;
  final String? brandPricePreference;
  final String? digitalAdoption;

  // Meta
  final String? createdAt;
  final String? createdByName;

  // Approval
  final String? submittedAt;
  final String? approvalStatus;   // null / 'pending' / 'approved' / 'rejected'
  final String? rejectionReason;

  NewDoctor({
    this.id,
    required this.firstName,
    required this.surname,
    required this.doctorProfile,
    this.ageGroup,
    required this.specialtyQualification,
    required this.specialtyPracticeType,
    this.patientsPerDay,
    this.daysAvailable = const [],
    this.routeId,
    this.routeName,
    required this.mobile,
    this.whatsapp = '',
    this.email = '',
    this.address = '',
    this.town = '',
    this.city = '',
    this.pin = '',
    this.businessPotential,
    this.isKbl = false,
    this.isFrd = false,
    this.isRemaining = false,
    this.visitCategory,
    this.doctorRegNo,
    this.dateOfBirth,
    this.marriageAnniversary,
    this.clinicOpeningDay,
    this.interests,
    this.prescriptionMode,
    this.linkedin,
    this.instagram,
    this.website,
    this.youtube,
    this.prescriptionPadImage,
    this.visitingCardImage,
    this.signBoardImage,
    this.clinicalMindset,
    this.earlyAdopter = false,
    this.brandLoyalty = false,
    this.brandPricePreference,
    this.digitalAdoption,
    this.createdAt,
    this.createdByName,
    this.submittedAt,
    this.approvalStatus,
    this.rejectionReason,
  });

  String get fullName => '$firstName $surname'.trim();

  String get initials {
    final fn = firstName.isNotEmpty ? firstName[0] : '';
    final sn = surname.isNotEmpty ? surname[0] : '';
    return '$fn$sn'.toUpperCase();
  }

  String get visitCategoryLabel {
    switch (visitCategory) {
      case 'CORE_3':    return '3V Core';
      case 'FRD_2':     return '2V FRD';
      case 'KBL':       return 'KBL';
      case 'REMAINING': return 'Remaining';
      default:          return 'Unset';
    }
  }

  factory NewDoctor.fromJson(Map<String, dynamic> json) {
    List<String> days = [];
    final daysRaw = json['days_available'];
    if (daysRaw is String && daysRaw.isNotEmpty) {
      days = daysRaw.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    } else if (daysRaw is List) {
      days = List<String>.from(daysRaw);
    }

    return NewDoctor(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      surname: json['surname'] ?? '',
      doctorProfile: json['doctor_profile'] ?? 'T',
      ageGroup: json['age_group'],
      specialtyQualification: json['specialty_qualification'] ?? '',
      specialtyPracticeType: json['specialty_practice_type'] ?? '',
      patientsPerDay: json['patients_per_day'] != null
          ? int.tryParse(json['patients_per_day'].toString())
          : null,
      daysAvailable: days,
      routeId: json['route_id'] != null
          ? int.tryParse(json['route_id'].toString())
          : null,
      routeName: json['route_name'],
      mobile: json['mobile'] ?? '',
      whatsapp: json['whatsapp'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      town: json['town'] ?? '',
      city: json['city'] ?? '',
      pin: json['pin'] ?? '',
      businessPotential: json['business_potential'] != null
          ? double.tryParse(json['business_potential'].toString())
          : null,
      isKbl: json['is_kbl'] == 1 || json['is_kbl'] == true,
      isFrd: json['is_frd'] == 1 || json['is_frd'] == true,
      isRemaining: json['is_remaining'] == 1 || json['is_remaining'] == true,
      visitCategory: json['visit_category'],
      doctorRegNo: json['doctor_reg_no'],
      dateOfBirth: json['date_of_birth'],
      marriageAnniversary: json['marriage_anniversary'],
      clinicOpeningDay: json['clinic_opening_day'],
      interests: json['interests'],
      prescriptionMode: json['prescription_mode'],
      linkedin: json['linkedin'],
      instagram: json['instagram'],
      website: json['website'],
      youtube: json['youtube'],
      prescriptionPadImage: json['prescription_pad_image'],
      visitingCardImage: json['visiting_card_image'],
      signBoardImage: json['sign_board_image'],
      clinicalMindset: json['clinical_mindset'],
      earlyAdopter: json['early_adopter'] == 1 || json['early_adopter'] == true,
      brandLoyalty: json['brand_loyalty'] == 1 || json['brand_loyalty'] == true,
      brandPricePreference: json['brand_price_preference'],
      digitalAdoption: json['digital_adoption'],
      createdAt: json['created_at'],
      createdByName: json['created_by_name'],
      submittedAt: json['submitted_at'],
      approvalStatus: json['approval_status'],
      rejectionReason: json['rejection_reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'first_name': firstName,
      'surname': surname,
      'doctor_profile': doctorProfile,
      'age_group': ageGroup,
      'specialty_qualification': specialtyQualification,
      'specialty_practice_type': specialtyPracticeType,
      'patients_per_day': patientsPerDay,
      'days_available': daysAvailable.join(','),
      'route_id': routeId,
      'route_name': routeName,
      'mobile': mobile,
      'whatsapp': whatsapp,
      'email': email,
      'address': address,
      'town': town,
      'city': city,
      'pin': pin,
      'business_potential': businessPotential,
      'is_kbl': isKbl ? 1 : 0,
      'is_frd': isFrd ? 1 : 0,
      'is_remaining': isRemaining ? 1 : 0,
      'visit_category': visitCategory,
      'doctor_reg_no': doctorRegNo,
      'date_of_birth': dateOfBirth,
      'marriage_anniversary': marriageAnniversary,
      'clinic_opening_day': clinicOpeningDay,
      'interests': interests,
      'prescription_mode': prescriptionMode,
      'linkedin': linkedin,
      'instagram': instagram,
      'website': website,
      'youtube': youtube,
      'clinical_mindset': clinicalMindset,
      'early_adopter': earlyAdopter ? 1 : 0,
      'brand_loyalty': brandLoyalty ? 1 : 0,
      'brand_price_preference': brandPricePreference,
      'digital_adoption': digitalAdoption,
    };
  }
}
