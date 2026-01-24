class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String city;
  final String memberSince;
  final bool isVerified;
  final String role;

  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.memberSince,
    required this.isVerified,
    required this.role,
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? city,
    String? memberSince,
    bool? isVerified,
    String? role,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      memberSince: memberSince ?? this.memberSince,
      isVerified: isVerified ?? this.isVerified,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'city': city,
        'memberSince': memberSince,
        'isVerified': isVerified,
        'role': role,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        city: json['city'] as String? ?? '',
        memberSince: json['memberSince'] as String? ?? 'Member since 2022',
        isVerified: json['isVerified'] as bool? ?? false,
        role: json['role'] as String? ?? 'User',
      );
}

/// Simple in-memory catalog of demo users for each role.
class UserProfiles {
  static const UserProfile admin = UserProfile(
    name: 'Admin User',
    email: 'admin@example.com',
    phone: '+91 98765 43210',
    city: 'BENGALURU URBAN',
    memberSince: 'Member since 2020',
    isVerified: true,
    role: 'Admin',
  );

  static const UserProfile owner = UserProfile(
    name: 'Owner Account',
    email: 'owner@example.com',
    phone: '+91 90000 12345',
    city: 'BENGALURU URBAN',
    memberSince: 'Member since 2021',
    isVerified: true,
    role: 'Owner',
  );

  static const UserProfile user = UserProfile(
    name: 'Regular User',
    email: 'user@example.com',
    phone: '+91 88888 11111',
    city: 'BENGALURU URBAN',
    memberSince: 'Member since 2022',
    isVerified: false,
    role: 'User',
  );

  static const UserProfile defaultProfile = user;

  static UserProfile forRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return admin;
      case 'owner':
        return owner;
      case 'user':
        return user;
      default:
        return defaultProfile;
    }
  }
}
