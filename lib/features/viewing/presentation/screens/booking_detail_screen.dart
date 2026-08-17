import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/app_failure.dart';
import '../../../property/presentation/providers/property_providers.dart';
import '../../../property/presentation/screens/property_detail_screen.dart';
import '../../domain/entities/viewing.dart';
import '../providers/viewing_providers.dart';
import '../../../property/domain/repositories/property_repository.dart' show Success, Failure;

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.viewing});
  final Viewing viewing;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _cancelling = false;
  String? _errorMessage;

  bool get _canCancel =>
      widget.viewing.status == ViewingStatus.requested || widget.viewing.status == ViewingStatus.confirmed;

  Future<void> _cancel() async {
    setState(() {
      _cancelling = true;
      _errorMessage = null;
    });

    final repo = ref.read(viewingRepositoryProvider);
    final result = await repo.cancel(widget.viewing.id);

    if (!mounted) return;

    switch (result) {
      case Success<Viewing>():
        ref.invalidate(myViewingsProvider);
        Navigator.of(context).pop();
      case Failure<Viewing>(:final failure):
        setState(() {
          _cancelling = false;
          _errorMessage = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewing = widget.viewing;
    final propertyAsync = ref.watch(propertyByIdProvider(viewing.propertyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          propertyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              error is AppFailure ? error.message : 'Could not load property details.',
            ),
            data: (property) => Card(
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: property.id)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(property.title, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text('${property.addressLine}, ${property.city}'),
                            const SizedBox(height: 4),
                            Text(property.formattedPrice, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Viewing', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _DetailRow(icon: Icons.calendar_today_outlined, label: _formatDateTime(viewing.scheduledAt)),
          const SizedBox(height: 8),
          _DetailRow(icon: Icons.timer_outlined, label: '${viewing.durationMins} minutes'),
          const SizedBox(height: 8),
          _DetailRow(icon: Icons.info_outline, label: _statusLabel(viewing.status)),
          if (viewing.notes != null && viewing.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Notes', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(viewing.notes!),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_canCancel) ...[
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: _cancelling ? null : _cancel,
              icon: _cancelling
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cancel_outlined),
              label: const Text('Cancel booking'),
            ),
          ],
        ],
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

  String _statusLabel(ViewingStatus status) {
    return switch (status) {
      ViewingStatus.requested => 'Awaiting agent confirmation',
      ViewingStatus.confirmed => 'Confirmed',
      ViewingStatus.cancelled => 'Cancelled',
      ViewingStatus.completed => 'Completed',
      ViewingStatus.noShow => 'No-show',
    };
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
