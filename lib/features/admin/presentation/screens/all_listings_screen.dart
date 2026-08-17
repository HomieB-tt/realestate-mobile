import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/app_failure.dart';
import '../../../property/domain/entities/property.dart';
import '../../../property/domain/repositories/property_repository.dart' show Success, Failure;
import '../../../property/presentation/providers/property_providers.dart';
import '../../../property/presentation/screens/property_detail_screen.dart';
import '../providers/admin_providers.dart';

class AllListingsScreen extends ConsumerWidget {
  const AllListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(adminAllPropertiesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminAllPropertiesProvider.future),
      child: propertiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(error is AppFailure ? error.message : 'Something went wrong.'),
        ),
        data: (properties) {
          if (properties.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: const Center(child: Text('No listings exist yet.')),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: properties.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) => _AdminPropertyTile(property: properties[index]),
          );
        },
      ),
    );
  }
}

class _AdminPropertyTile extends ConsumerStatefulWidget {
  const _AdminPropertyTile({required this.property});
  final Property property;

  @override
  ConsumerState<_AdminPropertyTile> createState() => _AdminPropertyTileState();
}

class _AdminPropertyTileState extends ConsumerState<_AdminPropertyTile> {
  bool _deleting = false;

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('This permanently removes "${widget.property.title}" and all its bookings.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);

    final repo = ref.read(propertyRepositoryProvider);
    final result = await repo.remove(widget.property.id);

    if (!mounted) return;

    switch (result) {
      case Success<void>():
        ref.invalidate(adminAllPropertiesProvider);
      case Failure<void>(:final failure):
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: ${failure.message}')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final property = widget.property;

    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: property.id)),
        ),
        title: Text(property.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${property.city}, ${property.country} · ${property.status.name}'),
        trailing: _deleting
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                onPressed: _confirmAndDelete,
              ),
      ),
    );
  }
}
