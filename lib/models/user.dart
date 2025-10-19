enum UserRole { guest, wirt, mobile, admin }

class UserAccount {
  final String username;
  final String password;
  final UserRole role;
  final String? assignedPubId; // falls Wirt oder mobile Einheit einer Kneipe zugeordnet ist

  UserAccount({
    required this.username,
    required this.password,
    required this.role,
    this.assignedPubId,
  });
}
