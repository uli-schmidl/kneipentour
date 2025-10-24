import 'package:kneipentour/models/user.dart';


List<UserAccount> users = [
  UserAccount(
    username: "admin",
    password: "reser1234",
    role: UserRole.admin,
  ),
  UserAccount(
    username: "nobbi",
    password: "holzkiste",
    role: UserRole.wirt,
    assignedPubId: "pub_holzkiste",
  ),
  UserAccount(
    username: "uli",
    password: "einsatz",
    role: UserRole.mobile,
    assignedPubId: "mobile_unit",
  ),
];
