import 'package:geolocator/geolocator.dart';

/// Result of a location lookup attempt. Modeled explicitly (rather than
/// throwing) because "permission denied" and "location services off" are
/// expected, common outcomes here — not exceptional ones — and the UI
/// needs to distinguish them to show the right message/action.
sealed class LocationResult {
  const LocationResult();
}

class LocationSuccess extends LocationResult {
  const LocationSuccess(this.lng, this.lat);
  final double lng;
  final double lat;
}

class LocationServiceDisabled extends LocationResult {
  const LocationServiceDisabled();
}

class LocationPermissionDenied extends LocationResult {
  const LocationPermissionDenied({required this.permanently});
  final bool permanently;
}

class LocationUnknownError extends LocationResult {
  const LocationUnknownError(this.message);
  final String message;
}

/// Thin wrapper around `geolocator`. Kept as a plain class (not a
/// Riverpod provider) since it has no state of its own — callers inject
/// or instantiate directly.
class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationServiceDisabled();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationPermissionDenied(permanently: false);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationPermissionDenied(permanently: true);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      return LocationSuccess(position.longitude, position.latitude);
    } catch (e) {
      return LocationUnknownError(e.toString());
    }
  }
}
