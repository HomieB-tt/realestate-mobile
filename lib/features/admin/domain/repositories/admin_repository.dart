import '../../../auth/domain/entities/app_user.dart';
import '../../../property/domain/entities/property.dart';
import '../../../property/domain/repositories/property_repository.dart' show Result;
import '../entities/admin_user_summary.dart';

/// Contract for admin-only operations: user management and unrestricted
/// property visibility. All calls hit /admin/* backend routes, which are
/// gated by requireRole('admin') server-side — RLS does not apply to
/// these (they run through the backend's service-role Supabase client),
/// so the backend's own role check is the only thing standing between a
/// non-admin and these operations. Never call these endpoints from a
/// context that hasn't already confirmed the signed-in user is an admin.
abstract interface class AdminRepository {
  Future<Result<List<AdminUserSummary>>> listUsers();
  Future<Result<AdminUserSummary>> updateUserRole(String userId, UserRole role);
  Future<Result<List<Property>>> listAllProperties();
}
