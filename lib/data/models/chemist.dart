class Chemist {
  final int id;
  final String name;
  final String area;
  final String? territoryType;
  final String? address;
  final String? pincode;
  final String? contactPerson;
  final String? mobile;

  Chemist({
    required this.id,
    required this.name,
    required this.area,
    this.territoryType,
    this.address,
    this.pincode,
    this.contactPerson,
    this.mobile,
  });

  factory Chemist.fromJson(Map<String, dynamic> json) {
    return Chemist(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Unknown Chemist',
      area: json['area']?.toString() ?? 'Unknown Area',
      territoryType:
          json['territory_type']?.toString() ??
          json['territoryType']?.toString(),
      address: json['address']?.toString(),
      pincode: json['pincode']?.toString(),
      contactPerson:
          json['contact_person']?.toString() ??
          json['contactPerson']?.toString(),
      mobile: json['mobile']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'area': area,
      'territory_type': territoryType,
      'address': address,
      'pincode': pincode,
      'contact_person': contactPerson,
      'mobile': mobile,
    };
  }
}
