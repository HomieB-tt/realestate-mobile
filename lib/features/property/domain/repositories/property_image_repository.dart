import 'dart:typed_data';
import '../../../../core/error/app_failure.dart';

class PropertyImage {
  const PropertyImage({
    required this.id,
    required this.propertyId,
    required this.publicUrl,
    required this.position,
    required this.isCover,
  });

  final String id;
  final String propertyId;
  final String publicUrl;
  final int position;
  final bool isCover;
}

sealed class ImageResult<T> {
  const ImageResult();
}

class ImageSuccess<T> extends ImageResult<T> {
  const ImageSuccess(this.value);
  final T value;
}

class ImageFailure<T> extends ImageResult<T> {
  const ImageFailure(this.failure);
  final AppFailure failure;
}

/// Contract for property image storage.
///
/// Deliberately NOT routed through the custom backend: the architecture
/// spec calls out Supabase Storage directly for image upload, and the
/// backend was never given a `property_images` endpoint. This repository
/// talks to Supabase directly using the signed-in user's own session, so
/// the existing `property_images` RLS policies (owner-or-admin can
/// mutate; visibility mirrors the parent property) are what actually
/// enforce authorization here — there's no server-side check to fall
/// back on for this one table.
abstract interface class PropertyImageRepository {
  Future<ImageResult<PropertyImage>> upload({
    required String propertyId,
    required Uint8List bytes,
    required String fileExtension,
    required int position,
    required bool isCover,
  });

  Future<ImageResult<List<PropertyImage>>> listForProperty(String propertyId);

  Future<ImageResult<void>> delete(String imageId);
}
