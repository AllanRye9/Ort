import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';

class AdminContentScreen extends ConsumerStatefulWidget {
  const AdminContentScreen({super.key});

  @override
  ConsumerState<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends ConsumerState<AdminContentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Moderation'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Properties'),
            Tab(text: 'Agriculture'),
            Tab(text: 'Manufacturing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ContentList(type: 'properties'),
          _ContentList(type: 'agriculture'),
          _ContentList(type: 'manufacturing'),
        ],
      ),
    );
  }
}

class _ContentList extends ConsumerStatefulWidget {
  const _ContentList({required this.type});
  final String type;

  @override
  ConsumerState<_ContentList> createState() => _ContentListState();
}

class _ContentListState extends ConsumerState<_ContentList> {
  List<Map<String, dynamic>> _items = [];
  int _total = 0;
  bool _loading = false;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      Map<String, dynamic> data;
      switch (widget.type) {
        case 'agriculture':
          data = await api.getAdminAgriculture(statusFilter: _statusFilter);
          _items = List<Map<String, dynamic>>.from(
              data['listings'] as List? ?? []);
          break;
        case 'manufacturing':
          data = await api.getAdminManufacturing(statusFilter: _statusFilter);
          _items = List<Map<String, dynamic>>.from(
              data['products'] as List? ?? []);
          break;
        default:
          data = await api.getAdminProperties(statusFilter: _statusFilter);
          _items = List<Map<String, dynamic>>.from(
              data['properties'] as List? ?? []);
      }
      if (mounted) {
        setState(() {
          _total = data['total'] as int? ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> item, String newStatus) async {
    try {
      final api = ref.read(apiServiceProvider);
      final id = item['id'] as int;
      switch (widget.type) {
        case 'agriculture':
          await api.updateAdminAgricultureStatus(id, newStatus);
          break;
        case 'manufacturing':
          await api.updateAdminManufacturingStatus(id, newStatus);
          break;
        default:
          await api.updateAdminPropertyStatus(id, newStatus);
      }
      _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteProperty(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        if (widget.type == 'properties') {
          await ref.read(apiServiceProvider).deleteAdminProperty(id);
        }
        _fetch();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = widget.type == 'properties'
        ? ['available', 'sold', 'rented', 'pending']
        : ['available', 'sold_out', 'draft'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text('$_total items',
                  style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              DropdownButton<String>(
                value: _statusFilter,
                hint: const Text('Filter'),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('All')),
                  ...statuses.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s))),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v);
                  _fetch();
                },
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (ctx, i) {
              final item = _items[i];
              final title = item['title'] as String? ??
                  item['name'] as String? ??
                  'Item ${item['id']}';
              final currentStatus = item['status'] as String? ?? 'unknown';
              return ListTile(
                title: Text(title),
                subtitle:
                    Text('ID: ${item['id']} · Status: $currentStatus'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (s) => _updateStatus(item, s),
                      itemBuilder: (_) => statuses
                          .map((s) =>
                              PopupMenuItem(value: s, child: Text(s)))
                          .toList(),
                    ),
                    if (widget.type == 'properties')
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 20),
                        onPressed: () =>
                            _deleteProperty(item['id'] as int),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
