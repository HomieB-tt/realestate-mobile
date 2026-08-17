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
/// via `ref.read(...).state = ...`; `nearbyPropertiesProvider` reacts
/// automatically since it watches this provider.
final searchParamsProvider = StateProvider<RadiusSearchParams?>((ref) => null);

/// City name currently being searched, if the user has switched to city
/// search mode. Null means "use location-based radius search instead".
/// Setting this takes priority over `searchParamsProvider` in
/// `nearbyPropertiesProvider` below.
final citySearchProvider = StateProvider<String?>((ref) => null);

/// Fetches published properties for the current search — either a city
/// search (if `citySearchProvider` is set) or a location-radius search
/// (via `searchParamsProvider`) otherwise. Returns an empty list (rather
/// than erroring) until a search has been performed, so the UI can
/// distinguish "no search yet" from "0 results" at the screen level.
final nearbyPropertiesProvider = FutureProvider.autoDispose<List<Property>>((ref) async {
  final repo = ref.watch(propertyRepositoryProvider);
  final city = ref.watch(citySearchProvider);

  if (city != null && city.trim().isNotEmpty) {
    final result = await repo.searchByCity(city.trim());
    return switch (result) {
      Success(:final value) => value,
      Failure(:final failure) => throw failure,
    };
  }

  final params = ref.watch(searchParamsProvider);
  if (params == null) return const [];

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
