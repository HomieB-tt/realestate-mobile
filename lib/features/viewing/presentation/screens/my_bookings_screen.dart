import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/app_failure.dart';
import '../../domain/entities/viewing.dart';
import '../providers/viewing_providers.dart';
import 'booking_detail_screen.dart';
import '../../../property/domain/repositories/property_repository.dart' show Success, Failure;

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewingsAsync = ref.watch(myViewingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myViewingsProvider.future),
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
                    child: const Center(child: Text('No bookings yet.')),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: viewings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _BookingTile(viewing: viewings[index]),
            );
          },
        ),
      ),
    );
  }
}

class _BookingTile extends ConsumerStatefulWidget {
  const _BookingTile({required this.viewing});
  final Viewing viewing;

  @override
  ConsumerState<_BookingTile> createState() => _BookingTileState();
}

class _BookingTileState extends ConsumerState<_BookingTile> {
  bool _cancelling = false;

  bool get _canCancel =>
      widget.viewing.status == ViewingStatus.requested || widget.viewing.status == ViewingStatus.confirmed;

  Future<void> _cancel() async {
    setState(() => _cancelling = true);

    final repo = ref.read(viewingRepositoryProvider);
    final result = await repo.cancel(widget.viewing.id);

    if (!mounted) return;

    setState(() => _cancelling = false);

    switch (result) {
      case Success<Viewing>():
        ref.invalidate(myViewingsProvider);
      case Failure<Viewing>(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel: ${failure.message}')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewing = widget.viewing;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookingDetailScreen(viewing: viewing)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(viewing.scheduledAt),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    _StatusLabel(status: viewing.status),
                  ],
                ),
              ),
              if (_canCancel)
                _cancelling
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(onPressed: _cancel, child: const Text('Cancel'))
              else
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
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

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});
  final ViewingStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      ViewingStatus.requested => ('Awaiting confirmation', Colors.orange),
      ViewingStatus.confirmed => ('Confirmed', theme.colorScheme.primary),
      ViewingStatus.cancelled => ('Cancelled', theme.colorScheme.outline),
      ViewingStatus.completed => ('Completed', theme.colorScheme.outline),
      ViewingStatus.noShow => ('No-show', Colors.red),
    };
    return Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color));
  }
}
