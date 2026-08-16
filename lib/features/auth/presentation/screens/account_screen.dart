import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load account.')),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CircleAvatar(
                radius: 32,
                child: Text(
                  (user.email ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(height: 16),
              Text(user.email ?? 'Unknown', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Role: ${user.role.name}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  final repo = ref.read(authRepositoryProvider);
                  await repo.signOut();
                  // currentUserProvider re-resolves automatically via
                  // authStateChangesProvider, which routes back to
                  // LoginScreen through _RootGate — no manual navigation
                  // needed here.
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }
}
