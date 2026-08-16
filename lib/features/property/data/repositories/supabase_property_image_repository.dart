import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/app_failure.dart';
import '../../domain/repositories/property_image_repository.dart';

const _bucket = 'property-images';

class SupabasePropertyImageRepository implements PropertyImageRepository {
  SupabasePropertyImageRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ImageResult<PropertyImage>> upload({
    required String propertyId,
    required Uint8List bytes,
    required String fileExtension,
    required int position,
    required bool isCover,
  }) async {
    try {
      final imageId = _generateId();
      final storagePath = '$propertyId/$imageId.$fileExtension';

      // 1. Upload the file bytes to Storage. RLS on storage.objects (see
      //    migration 001) permits any authenticated user to write to this
      //    bucket — ownership is enforced at the `property_images` table
      //    level instead, in step 2 below.
      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: _contentTypeFor(fileExtension), upsert: false),
          );

      // 2. Record the row in `property_images`. This INSERT is what RLS
      //    actually gates on ownership: `property_images_mutate_owner_or_admin`
      //    checks that the parent property's agent_id matches auth.uid().
      //    If this user doesn't own the property, this insert is rejected
      //    by Postgres regardless of whether step 1 succeeded — worth
      //    noting there's a brief window where an orphaned Storage object
      //    could exist if this step fails; acceptable for MVP, a cleanup
      //    job could reconcile orphans later if needed.
      final row = await _client
          .from('property_images')
          .insert({
            'id': imageId,
            'property_id': propertyId,
            'storage_path': storagePath,
            'position': position,
            'is_cover': isCover,
          })
          .select()
          .single();

      final publicUrl = _client.storage.from(_bucket).getPublicUrl(storagePath);

      return ImageSuccess(
        PropertyImage(
          id: row['id'] as String,
          propertyId: row['property_id'] as String,
          publicUrl: publicUrl,
          position: row['position'] as int,
          isCover: row['is_cover'] as bool,
        ),
      );
    } on StorageException catch (e) {
      return ImageFailure(UnknownFailure('Upload failed: ${e.message}'));
    } on PostgrestException catch (e) {
      return ImageFailure(ForbiddenFailure(e.message));
    } catch (e) {
      return const ImageFailure(NetworkFailure());
    }
  }

  @override
  Future<ImageResult<List<PropertyImage>>> listForProperty(String propertyId) async {
    try {
      final rows = await _client
          .from('property_images')
          .select()
          .eq('property_id', propertyId)
          .order('position');

      final images = (rows as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        final publicUrl = _client.storage.from(_bucket).getPublicUrl(map['storage_path'] as String);
        return PropertyImage(
          id: map['id'] as String,
          propertyId: map['property_id'] as String,
          publicUrl: publicUrl,
          position: map['position'] as int,
          isCover: map['is_cover'] as bool,
        );
      }).toList();

      return ImageSuccess(images);
    } on PostgrestException catch (e) {
      return ImageFailure(UnknownFailure(e.message));
    } catch (e) {
      return const ImageFailure(NetworkFailure());
    }
  }

  @override
  Future<ImageResult<void>> delete(String imageId) async {
    try {
      await _client.from('property_images').delete().eq('id', imageId);
      return const ImageSuccess(null);
    } on PostgrestException catch (e) {
      return ImageFailure(ForbiddenFailure(e.message));
    } catch (e) {
      return const ImageFailure(NetworkFailure());
    }
  }

  String _generateId() {
    // Simple client-generated UUID-like id without pulling in the `uuid`
    // package as a new dependency — sufficient uniqueness for a storage
    // path segment. Swap for package:uuid if collision-safety needs to
    // be provable rather than just extremely likely.
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = (now * 2654435761) % 4294967296;
    return '${now.toRadixString(16)}${rand.toRadixString(16)}';
  }

  String _contentTypeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
