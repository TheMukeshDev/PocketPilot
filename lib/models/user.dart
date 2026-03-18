class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.token,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? token;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
    };
  }
}
