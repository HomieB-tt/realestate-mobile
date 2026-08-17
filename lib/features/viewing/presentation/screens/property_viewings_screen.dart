import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/app_failure.dart';
import '../../domain/entities/viewing.dart';
import '../providers/viewing_providers.dart';
import '../../../property/domain/repositories/property_repository.dart' show Success, Failure;

/// Agent-facing view of booking requests on one of their properties.
/// Reachable from the property detail screen when the signed-in user
/// owns that listing. The backend only exposes viewings scoped to a
/// single property (GET /viewings/property/:propertyId) — there's no
/// "all my viewings across every listing" endpoint — so this screen is
/// necessarily per-property rather than a single aggregate inbox.
class PropertyViewingsScreen extends ConsumerWidget {
  const PropertyViewingsScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewingsAsync = ref.watch(viewingsForPropertyProvider(propertyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking requests')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(viewingsForPropertyProvider(propertyId).future),
        child: viewingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(error is AppFailure ? error.message : 'Something went wrong.'),
          ),
          data: (viewings) {
            if (viewings.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: const Center(child: Text('No booking requests yet.')),
                  ),
                ),
              );
            }

            // Soonest-scheduled first, regardless of what order the API
            // returned them in — makes the pending queue easier to work
            // through top-to-bottom.
            final sorted = [...viewings]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _ViewingRequestTile(
                viewing: sorted[index],
                propertyId: propertyId,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ViewingRequestTile extends ConsumerStatefulWidget {
  const _ViewingRequestTile({required this.viewing, required this.propertyId});
  final Viewing viewing;
  final String propertyId;

  @override
  ConsumerState<_ViewingRequestTile> createState() => _ViewingRequestTileState();
}

class _ViewingRequestTileState extends ConsumerState<_ViewingRequestTile> {
  bool _busy = false;
  String? _errorMessage;

  Future<void> _confirmAction() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final repo = ref.read(viewingRepositoryProvider);
    final result = await repo.confirm(widget.viewing.id);
    if (!mounted) return;
    switch (result) {
      case Success<Viewing>():
        ref.invalidate(viewingsForPropertyProvider(widget.propertyId));
      case Failure<Viewing>(:final failure):
        setState(() {
          _busy = false;
          _errorMessage = failure.message;
        });
    }
  }

  Future<void> _declineAction() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final repo = ref.read(viewingRepositoryProvider);
    final result = await repo.cancel(widget.viewing.id);
    if (!mounted) return;
    switch (result) {
      case Success<Viewing>():
        ref.invalidate(viewingsForPropertyProvider(widget.propertyId));
      case Failure<Viewing>(:final failure):
        setState(() {
          _busy = false;
          _errorMessage = failure.message;
        });
    }
  }

  bool get _isPending => widget.viewing.status == ViewingStatus.requested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewing = widget.viewing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDateTime(viewing.scheduledAt), style: theme.textTheme.titleSmall),
                _StatusChip(status: viewing.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('${viewing.durationMins} min viewing', style: theme.textTheme.bodySmall),
            if (viewing.notes != null && viewing.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(viewing.notes!, style: theme.textTheme.bodyMedium),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (_isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _declineAction,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy ? null : _confirmAction,
                      child: _busy
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ViewingStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      ViewingStatus.requested => ('Pending', Colors.orange),
      ViewingStatus.confirmed => ('Confirmed', theme.colorScheme.primary),
      ViewingStatus.cancelled => ('Declined', theme.colorScheme.outline),
      ViewingStatus.completed => ('Completed', theme.colorScheme.outline),
      ViewingStatus.noShow => ('No-show', Colors.red),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
