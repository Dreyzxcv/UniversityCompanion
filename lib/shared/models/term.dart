class Term {
  final String id;
  final String name;
  final String schoolYear;
  final bool isActive;

  Term({
    required this.id,
    required this.name,
    required this.schoolYear,
    required this.isActive,
  });

  factory Term.fromMap(String id, Map<String, dynamic> map) {
    return Term(
      id: id,
      name: map['name'] ?? '',
      schoolYear: map['schoolYear'] ?? '',
      isActive: map['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'schoolYear': schoolYear,
      'isActive': isActive,
    };
  }

  Term copyWith({String? name, String? schoolYear, bool? isActive}) {
    return Term(
      id: id,
      name: name ?? this.name,
      schoolYear: schoolYear ?? this.schoolYear,
      isActive: isActive ?? this.isActive,
    );
  }
}
