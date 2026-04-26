import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _targetRole;
  bool _sending = false;

  final _roles = ['user', 'agent', 'company', 'organization', 'admin'];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(apiServiceProvider).broadcastNotification(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            targetRole: _targetRole,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification broadcast sent!')),
        );
        _titleController.clear();
        _bodyController.clear();
        setState(() { _targetRole = null; _sending = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast Notification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send a notification to all users or a specific role group.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _targetRole,
              decoration: const InputDecoration(
                  labelText: 'Target Role (leave blank for all)'),
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('All Users')),
                ..._roles.map(
                    (r) => DropdownMenuItem(value: r, child: Text(r))),
              ],
              onChanged: (v) => setState(() => _targetRole = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration:
                  const InputDecoration(labelText: 'Notification Title'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message Body',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Broadcast'),
            ),
          ],
        ),
      ),
    );
  }
}
