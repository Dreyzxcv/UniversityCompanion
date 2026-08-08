class AppUser {
  final String uid;
  final String name;
  final String school;
  final String email;
  final bool verified;
  final String course;
  final String yearLevel;

  AppUser({
    required this.uid,
    required this.name,
    required this.school,
    required this.email,
    required this.verified,
    this.course = '',
    this.yearLevel = '',
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      school: map['school'] ?? '',
      email: map['email'] ?? '',
      verified: map['verified'] ?? false,
      course: map['course'] ?? '',
      yearLevel: map['yearLevel'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'school': school,
      'email': email,
      'verified': verified,
      'course': course,
      'yearLevel': yearLevel,
    };
  }
}