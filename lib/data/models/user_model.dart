class User {
  final int employeeId;
  final String employeeCode;
  final String firstName;
  final String? lastName;
  final String email;
  final String mobile;
  final String? designation;
  final String? headQtr;
  final String? division;
  final bool isFirstLogin;

  User({
    required this.employeeId,
    required this.employeeCode,
    required this.firstName,
    this.lastName,
    required this.email,
    required this.mobile,
    this.designation,
    this.headQtr,
    this.division,
    this.isFirstLogin = false,
  });

  // Factory: Create User object from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      employeeId: json['employee_id'] ?? 0,
      employeeCode: json['employee_code'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'],
      email: json['email'] ?? '',
      mobile: json['mobile'] ?? '',
      designation: json['designation'],
      headQtr: json['head_qtr'],
      division: json['division'] ?? "zf1",
      isFirstLogin: json['is_first_login'] == 1 || json['is_first_login'] == true,
    );
  }

  // Convert User object to JSON (for saving to Shared Prefs)
  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'employee_code': employeeCode,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'mobile': mobile,
      'designation': designation,
      'head_qtr': headQtr,
      'division': division,
    };
  }
  
  // Helper to get full name
  String get fullName => lastName != null ? "$firstName $lastName" : firstName;
}