class AppUser {
  final String uid;
  final String email;
  final String name;
  final String firstName;
  final String middleName;
  final String lastName;
  final String gender;
  final String phone;
  final String street;
  final String city;
  final String barangay;
  final String role; // 'owner' | 'user'
  final String createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    this.firstName = '',
    this.middleName = '',
    this.lastName = '',
    this.gender = 'Male',
    this.phone = '',
    this.street = '',
    this.city = '',
    this.barangay = '',
    required this.role,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      firstName: map['firstName'] ?? '',
      middleName: map['middleName'] ?? '',
      lastName: map['lastName'] ?? '',
      gender: map['gender'] ?? 'Male',
      phone: map['phone'] ?? '',
      street: map['street'] ?? map['houseNo'] ?? '',
      city: map['city'] ?? map['municipality'] ?? '',
      barangay: map['barangay'] ?? '',
      role: map['role'] ?? 'user',
      createdAt: map['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'name': name,
    'firstName': firstName,
    'middleName': middleName,
    'lastName': lastName,
    'gender': gender,
    'phone': phone,
    'street': street,
    'city': city,
    'barangay': barangay,
    'role': role,
    'createdAt': createdAt,
  };

  bool get isOwner => role == 'owner';
  bool get isUser => role == 'user';
}
