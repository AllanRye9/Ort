import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';

class AdminLogsScreen extends ConsumerStatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  ConsumerState<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends ConsumerState<AdminLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  int _total = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await ref.read(apiServiceProvider).getAdminLogs();
      if (mounted) {
        setState(() {
          _total = data['total'] as int? ?? 0;
          _logs = List<Map<String, dynamic>>.from(
              data['logs'] as List? ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Logs ($_total)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (ctx, i) {
                final log = _logs[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1B5E20),
                    child: Text(
                      '${log['admin_id'] ?? '?'}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                  title: Text(log['action'] as String? ?? ''),
                  subtitle: Text(
                    '${log['target_type'] ?? ''} #${log['target_id'] ?? ''}'
                    '${log['detail'] != null ? " · ${log['detail']}" : ""}',
                  ),
                  trailing: Text(
                    _formatDate(log['created_at']),
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11),
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
