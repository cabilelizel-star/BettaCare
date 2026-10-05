class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role; // 'owner' | 'user'
  final String createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'user',
      createdAt: map['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'name': name,
    'role': role,
    'createdAt': createdAt,
  };

  bool get isOwner => role == 'owner';
  bool get isUser => role == 'user';
}
