import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';

class AdminTicketsScreen extends ConsumerStatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  ConsumerState<AdminTicketsScreen> createState() =>
      _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends ConsumerState<AdminTicketsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  int _total = 0;
  bool _loading = false;
  String? _statusFilter;

  final _statuses = ['open', 'in_progress', 'resolved', 'closed'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await ref
          .read(apiServiceProvider)
          .getAdminTickets(statusFilter: _statusFilter);
      if (mounted) {
        setState(() {
          _total = data['total'] as int? ?? 0;
          _tickets = List<Map<String, dynamic>>.from(
              data['tickets'] as List? ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _openDetail(Map<String, dynamic> ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _TicketDetailScreen(ticketId: ticket['id'] as int),
      ),
    ).then((_) => _fetch());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Support Tickets ($_total)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Filter: ',
                    style: TextStyle(color: Colors.grey)),
                DropdownButton<String>(
                  value: _statusFilter,
                  hint: const Text('All'),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('All')),
                    ..._statuses.map(
                        (s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) {
                    setState(() => _statusFilter = v);
                    _fetch();
                  },
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _tickets.length,
              itemBuilder: (ctx, i) {
                final t = _tickets[i];
                final st = t['status'] as String? ?? 'open';
                return ListTile(
                  onTap: () => _openDetail(t),
                  title: Text(t['subject'] as String? ?? ''),
                  subtitle: Text(
                      'User #${t['user_id']} · ${t['created_at'] ?? ''}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(st).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _statusColor(st)),
                    ),
                    child: Text(
                      st,
                      style: TextStyle(
                          color: _statusColor(st),
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketDetailScreen extends ConsumerStatefulWidget {
  const _TicketDetailScreen({required this.ticketId});
  final int ticketId;

  @override
  ConsumerState<_TicketDetailScreen> createState() =>
      _TicketDetailScreenState();
}

class _TicketDetailScreenState
    extends ConsumerState<_TicketDetailScreen> {
  Map<String, dynamic>? _ticket;
  bool _loading = true;
  final _resolutionController = TextEditingController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _resolutionController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final data = await ref
          .read(apiServiceProvider)
          .getAdminTicket(widget.ticketId);
      if (mounted) {
        setState(() {
          _ticket = data;
          _selectedStatus = data['status'] as String?;
          _resolutionController.text =
              data['resolution'] as String? ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      await ref.read(apiServiceProvider).updateAdminTicket(
        widget.ticketId,
        {
          if (_selectedStatus != null) 'status': _selectedStatus,
          'resolution': _resolutionController.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ticket #${widget.ticketId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ticket == null
              ? const Center(child: Text('Not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ticket!['subject'] as String? ?? '',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'User #${_ticket!['user_id']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child:
                              Text(_ticket!['body'] as String? ?? ''),
                        ),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration:
                            const InputDecoration(labelText: 'Status'),
                        items: ['open', 'in_progress', 'resolved', 'closed']
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedStatus = v),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _resolutionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Resolution / Reply',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
