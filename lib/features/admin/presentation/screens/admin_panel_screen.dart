import 'package:flutter/material.dart';
import 'user_management_screen.dart';
import 'all_listings_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'All listings'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            UserManagementScreen(),
            AllListingsScreen(),
          ],
        ),
      ),
    );
  }
}
