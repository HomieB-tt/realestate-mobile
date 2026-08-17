import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/api_admin_repository.dart';
import '../../domain/entities/admin_user_summary.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../../property/domain/entities/property.dart';
import '../../../property/domain/repositories/property_repository.dart' show Success, Failure;

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return ApiAdminRepository(api);
});

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUserSummary>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final result = await repo.listUsers();

  return switch (result) {
    Success(:final value) => value,
    Failure(:final failure) => throw failure,
  };
});

final adminAllPropertiesProvider = FutureProvider.autoDispose<List<Property>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final result = await repo.listAllProperties();

  return switch (result) {
    Success(:final value) => value,
    Failure(:final failure) => throw failure,
  };
});
