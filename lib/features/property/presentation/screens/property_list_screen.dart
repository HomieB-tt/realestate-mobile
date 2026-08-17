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

  final _searchController = TextEditingController();
  bool _usingFallbackLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveLocationAndSearch());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocationAndSearch() async {
    // A city search stays active across a pull-to-refresh; only fall
    // back to re-resolving location when no city search is active.
    if (ref.read(citySearchProvider) != null) {
      ref.invalidate(nearbyPropertiesProvider);
      return;
    }

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

  void _submitCitySearch(String value) {
    final trimmed = value.trim();
    ref.read(citySearchProvider.notifier).state = trimmed.isEmpty ? null : trimmed;
  }

  void _clearCitySearch() {
    _searchController.clear();
    ref.read(citySearchProvider.notifier).state = null;
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(nearbyPropertiesProvider);
    final activeCitySearch = ref.watch(citySearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby listings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _submitCitySearch,
              decoration: InputDecoration(
                hintText: 'Search by city…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: activeCitySearch != null
                    ? IconButton(icon: const Icon(Icons.close), onPressed: _clearCitySearch)
                    : null,
              ),
            ),
          ),
          if (activeCitySearch != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing results for "$activeCitySearch" — clear to search near you instead.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else if (_usingFallbackLocation)
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
                          child: Center(
                            child: Text(
                              activeCitySearch != null
                                  ? 'No listings found in "$activeCitySearch".'
                                  : 'No listings found nearby yet.',
                            ),
                          ),
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
