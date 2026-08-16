import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/supabase_client.dart';
import '../../data/repositories/api_property_repository.dart';
import '../../data/repositories/supabase_property_image_repository.dart';
import '../../domain/entities/property.dart';
import '../../domain/repositories/property_image_repository.dart';
import '../../domain/repositories/property_repository.dart';

final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return ApiPropertyRepository(api);
});

/// Image upload goes straight to Supabase (Storage + the `property_images`
/// table via RLS), NOT through the custom backend — see
/// domain/repositories/property_image_repository.dart for why.
final propertyImageRepositoryProvider = Provider<PropertyImageRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabasePropertyImageRepository(client);
});

/// Search parameters currently applied by the user. Screens update this
/// via `ref.read(searchParamsProvider.notifier).updateParams(...)`; `nearbyPropertiesProvider` reacts
/// automatically since it watches this provider.
class SearchParamsNotifier extends Notifier<RadiusSearchParams?> {
  @override
  RadiusSearchParams? build() => null;

  void updateParams(RadiusSearchParams? newParams) {
    state = newParams;
  }
}

final searchParamsProvider = NotifierProvider<SearchParamsNotifier, RadiusSearchParams?>(SearchParamsNotifier.new);

/// Fetches nearby published properties for the current search params.
/// Returns an empty list (rather than erroring) until a search has been
/// performed, so the UI can distinguish "no search yet" from "0 results"
/// at the screen level if desired.
final nearbyPropertiesProvider = FutureProvider.autoDispose<List<Property>>((ref) async {
  final params = ref.watch(searchParamsProvider);
  if (params == null) return const [];

  final repo = ref.watch(propertyRepositoryProvider);
  final result = await repo.searchNearby(params);

  return switch (result) {
    Success(:final value) => value,
    Failure(:final failure) => throw failure,
  };
});

/// Properties owned by the currently signed-in agent — powers the
/// "My Listings" screen.
final myPropertiesProvider = FutureProvider.autoDispose<List<Property>>((ref) async {
  final repo = ref.watch(propertyRepositoryProvider);
  final result = await repo.listMine();

  return switch (result) {
    Success(:final value) => value,
    Failure(:final failure) => throw failure,
  };
});

/// Single-property lookup, keyed by id — used on the detail screen.
final propertyByIdProvider = FutureProvider.autoDispose.family<Property, String>((ref, id) async {
  final repo = ref.watch(propertyRepositoryProvider);
  final result = await repo.getById(id);

  return switch (result) {
    Success(:final value) => value,
    Failure(:final failure) => throw failure,
  };
});

/// Images for a given property — used on the detail screen's photo strip.
final propertyImagesProvider =
    FutureProvider.autoDispose.family<List<PropertyImage>, String>((ref, propertyId) async {
  final repo = ref.watch(propertyImageRepositoryProvider);
  final result = await repo.listForProperty(propertyId);

  return switch (result) {
    ImageSuccess(:final value) => value,
    ImageFailure(:final failure) => throw failure,
  };
});
