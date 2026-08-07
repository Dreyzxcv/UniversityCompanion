class AppUser {
  final String uid;
  final String name;
  final String school;
  final String email;
  final bool verified;

  AppUser({
    required this.uid,
    required this.name,
    required this.school,
    required this.email,
    required this.verified,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      school: map['school'] ?? '',
      email: map['email'] ?? '',
      verified: map['verified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'school': school,
      'email': email,
      'verified': verified,
    };
  }
}
