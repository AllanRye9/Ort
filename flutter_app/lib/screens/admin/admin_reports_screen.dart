import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() =>
      _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _days = 30;
  Map<String, dynamic>? _overviewData;
  Map<String, dynamic>? _usersData;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.getAdminReportsOverview(days: _days),
        api.getAdminReportsUsers(days: _days),
      ]);
      if (mounted) {
        setState(() {
          _overviewData = results[0];
          _usersData = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          DropdownButton<int>(
            value: _days,
            underline: const SizedBox(),
            dropdownColor: Colors.white,
            items: [7, 14, 30, 90, 365]
                .map((d) =>
                    DropdownMenuItem(value: d, child: Text('${d}d')))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _days = v);
                _fetch();
              }
            },
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Users')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(data: _overviewData),
                _UsersTab(data: _usersData),
              ],
            ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.grey))),
          Text(
            '$value',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Center(child: Text('No data'));
    final ordersByStatus =
        data!['orders_by_status'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity (last ${data!['period_days']}d)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  _StatRow(
                      label: 'New Users',
                      value: data!['new_users']),
                  _StatRow(
                      label: 'New Properties',
                      value: data!['new_properties']),
                  _StatRow(
                      label: 'New Orders',
                      value: data!['new_orders']),
                  _StatRow(
                      label: 'New Messages',
                      value: data!['new_messages']),
                  _StatRow(
                      label: 'Agriculture Listings',
                      value: data!['new_agriculture_listings']),
                  _StatRow(
                      label: 'Manufacturing Products',
                      value: data!['new_manufacturing_products']),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (ordersByStatus.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Orders by Status',
                        style:
                            Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    ...ordersByStatus.entries
                        .map((e) =>
                            _StatRow(label: e.key, value: e.value)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Center(child: Text('No data'));
    final byRole =
        data!['registrations_by_role'] as Map<String, dynamic>? ?? {};
    final totalByRole =
        data!['total_by_role'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Registrations (last ${data!['period_days']}d)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  ...byRole.entries
                      .map((e) => _StatRow(label: e.key, value: e.value)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All Time by Role',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Divider(),
                  ...totalByRole.entries
                      .map((e) => _StatRow(label: e.key, value: e.value)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
