import '../../../auth/domain/entities/app_user.dart';

class AdminUserSummary {
  const AdminUserSummary({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String? email;
  final String fullName;
  final UserRole role;
  final DateTime createdAt;

  String get displayName => fullName.isNotEmpty ? fullName : (email ?? id);
}
