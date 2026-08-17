import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/location/location_service.dart';
import '../../domain/repositories/property_repository.dart';
import '../providers/property_providers.dart';
import '../widgets/property_card.dart';
import 'property_detail_screen.dart';

/// Landing screen for clients: search nearby published listings.
/// Attempts real device geolocation first; falls back to a fixed demo
/// coordinate if location services/permissions aren't available, so the
/// screen is never just empty with no explanation.
class PropertyListScreen extends ConsumerStatefulWidget {
  const PropertyListScreen({super.key});

  @override
  ConsumerState<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends ConsumerState<PropertyListScreen> {
  static const _demoFallback = RadiusSearchParams(
    lng: 32.5825,
    lat: 0.3476,
    radiusMeters: 10000,
  );

  static const _locationService = LocationService();

  bool _usingFallbackLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveLocationAndSearch());
  }

  Future<void> _resolveLocationAndSearch() async {
    final result = await _locationService.getCurrentLocation();

    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final lng, :final lat):
        ref.read(searchParamsProvider.notifier).state = RadiusSearchParams(
          lng: lng,
          lat: lat,
          radiusMeters: 10000,
        );
      case LocationServiceDisabled():
      case LocationPermissionDenied():
      case LocationUnknownError():
        // Any failure to get a real location falls back to the demo
        // coordinate rather than leaving the screen stuck with no
        // search performed at all.
        setState(() => _usingFallbackLocation = true);
        ref.read(searchParamsProvider.notifier).state = _demoFallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(nearbyPropertiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby listings')),
      body: Column(
        children: [
          if (_usingFallbackLocation)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Showing listings near a default location — enable location access for results near you.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _resolveLocationAndSearch,
              child: propertiesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorView(
                  failure: error is AppFailure ? error : const UnknownFailure(),
                  onRetry: () => ref.invalidate(nearbyPropertiesProvider),
                ),
                data: (properties) {
                  if (properties.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: const Center(child: Text('No listings found nearby yet.')),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: properties.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final property = properties[index];
                      return PropertyCard(
                        property: property,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: property.id)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.failure, required this.onRetry});
  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(failure.message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
