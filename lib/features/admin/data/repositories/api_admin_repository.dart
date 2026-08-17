import 'package:dio/dio.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../property/data/dto/property_dto.dart';
import '../../../property/domain/entities/property.dart';
import '../../../property/domain/repositories/property_repository.dart' show Result, Success, Failure;
import '../../domain/entities/admin_user_summary.dart';
import '../../domain/repositories/admin_repository.dart';

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository(this._api);

  final ApiClient _api;

  static AdminUserSummary _userFromJson(Map<String, dynamic> json) {
    return AdminUserSummary(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['fullName'] as String,
      role: userRoleFromString(json['role'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  Future<Result<List<AdminUserSummary>>> listUsers() async {
    try {
      final response = await _api.get<Map<String, dynamic>>('/admin/users');
      final list = response.data!['data'] as List<dynamic>;
      return Success(list.map((e) => _userFromJson(e as Map<String, dynamic>)).toList());
    } on DioException catch (e) {
      return Failure(mapDioErrorToFailure(e));
    }
  }

  @override
  Future<Result<AdminUserSummary>> updateUserRole(String userId, UserRole role) async {
    try {
      final response = await _api.patch<Map<String, dynamic>>(
        '/admin/users/$userId/role',
        data: {'role': role.name},
      );
      return Success(_userFromJson(response.data!['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return Failure(mapDioErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<Property>>> listAllProperties() async {
    try {
      final response = await _api.get<Map<String, dynamic>>('/admin/properties');
      final list = response.data!['data'] as List<dynamic>;
      return Success(PropertyDto.listFromJson(list));
    } on DioException catch (e) {
      return Failure(mapDioErrorToFailure(e));
    }
  }
}
