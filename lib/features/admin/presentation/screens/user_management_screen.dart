import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/app_failure.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/admin_user_summary.dart';
import '../../../property/domain/repositories/property_repository.dart' show Success, Failure;
import '../providers/admin_providers.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUserId = currentUserAsync.valueOrNull?.id;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminUsersProvider.future),
      child: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(error is AppFailure ? error.message : 'Something went wrong.'),
        ),
        data: (users) {
          if (users.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: const Center(child: Text('No users found.')),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
              return _UserTile(
                user: user,
                isSelf: user.id == currentUserId,
              );
            },
          );
        },
      ),
    );
  }
}

class _UserTile extends ConsumerStatefulWidget {
  const _UserTile({required this.user, required this.isSelf});
  final AdminUserSummary user;
  final bool isSelf;

  @override
  ConsumerState<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends ConsumerState<_UserTile> {
  bool _updating = false;
  String? _errorMessage;

  Future<void> _changeRole(UserRole newRole) async {
    if (newRole == widget.user.role) return;

    setState(() {
      _updating = true;
      _errorMessage = null;
    });

    final repo = ref.read(adminRepositoryProvider);
    final result = await repo.updateUserRole(widget.user.id, newRole);

    if (!mounted) return;

    switch (result) {
      case Success<AdminUserSummary>():
        ref.invalidate(adminUsersProvider);
      case Failure<AdminUserSummary>(:final failure):
        setState(() {
          _updating = false;
          _errorMessage = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(child: Text(user.displayName.substring(0, 1).toUpperCase())),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email ?? user.fullName, style: theme.textTheme.titleSmall),
                  if (widget.isSelf) ...[
                    const SizedBox(height: 2),
                    Text('This is you', style: theme.textTheme.bodySmall),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                  ],
                ],
              ),
            ),
            _updating
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                // Disable changing your own role — mirrors the backend
                // guard against an admin locking themselves out.
                : DropdownButton<UserRole>(
                    value: user.role,
                    underline: const SizedBox.shrink(),
                    onChanged: widget.isSelf ? null : (role) => role != null ? _changeRole(role) : null,
                    items: UserRole.values
                        .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }
}
