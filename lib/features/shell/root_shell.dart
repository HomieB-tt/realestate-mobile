import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/domain/entities/app_user.dart';

import '../auth/presentation/screens/account_screen.dart';
import '../property/presentation/screens/my_properties_screen.dart';
import '../property/presentation/screens/property_list_screen.dart';
import '../viewing/presentation/screens/my_bookings_screen.dart';

/// Bottom-tab shell shown once a user is authenticated. Tab set adapts
/// to role: agents get a "My Listings" tab; clients don't (mirrors the
/// backend's own agent-only routes — no point showing UI for actions
/// that would just 403).
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAgent = widget.user.isAgent;

    final screens = [
      const PropertyListScreen(),
      const MyBookingsScreen(),
      if (isAgent) const MyPropertiesScreen(),
      const AccountScreen(),
    ];

    final destinations = [
      const NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Search'),
      const NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Bookings'),
      if (isAgent)
        const NavigationDestination(icon: Icon(Icons.home_work_outlined), selectedIcon: Icon(Icons.home_work), label: 'Listings'),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
    ];

    // Guard against a stale index if the tab set shrinks (e.g. role
    // changes at runtime, though uncommon) — clamp rather than crash on
    // an out-of-range IndexedStack index.
    final safeIndex = _index.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
