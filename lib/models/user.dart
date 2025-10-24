import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { guest, wirt, mobile, admin }

class UserAccount {
  final String username;
  final String password;
  final UserRole role;
  final String? assignedPubId;

  UserAccount({
    required this.username,
    required this.password,
    required this.role,
    this.assignedPubId,
  });

  factory UserAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAccount(
      username: data['username'] ?? '',
      password: data['password'] ?? '',
      role: _roleFromString(data['role'] ?? 'guest'),
      assignedPubId: data['assignedPubId'],
    );
  }

  static UserRole _roleFromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'wirt':
        return UserRole.wirt;
      case 'mobile':
        return UserRole.mobile;
      default:
        return UserRole.guest;
    }
  }
}
