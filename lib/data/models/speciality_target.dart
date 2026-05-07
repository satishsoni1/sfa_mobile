class SpecialityTarget {
  final String category;
  final List<String> specialities; // exact-match list
  final int quota;

  const SpecialityTarget({
    required this.category,
    required this.specialities,
    required this.quota,
  });

  factory SpecialityTarget.fromJson(Map<String, dynamic> json) {
    final spRaw = json['specialities'];
    return SpecialityTarget(
      category: json['category']?.toString() ?? '',
      specialities: spRaw is List
          ? List<String>.from(spRaw.map((e) => e.toString()))
          : <String>[],
      quota: (json['quota'] as num?)?.toInt() ?? 0,
    );
  }

  bool contains(String speciality) => specialities.contains(speciality);
}
