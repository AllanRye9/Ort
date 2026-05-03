import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final int conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _uploadingAttachment = false;
  bool _loading = true;
  String? _error;
  List<MessageModel> _messages = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_sending) _pollMessages();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(apiServiceProvider)
          .getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = data
              .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pollMessages() async {
    try {
      final data = await ref
          .read(apiServiceProvider)
          .getMessages(widget.conversationId);
      if (!mounted) return;
      final updated = data
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      // Only update state if there are new messages (compare last message ID)
      final lastId = _messages.isNotEmpty ? _messages.last.id : null;
      final newLastId = updated.isNotEmpty ? updated.last.id : null;
      if (newLastId != lastId || updated.length != _messages.length) {
        setState(() => _messages = updated);
        _scrollToBottom();
      }
    } catch (_) {
      // Silently ignore polling errors to avoid spamming the user
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmDelete(int messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final userId = ref.read(authProvider).userId;
      await ref.read(apiServiceProvider).deleteMessage(messageId, userId!);
      setState(() => _messages.removeWhere((m) => m.id == messageId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete message: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final userId = ref.read(authProvider).userId;
      await ref.read(apiServiceProvider).sendMessage({
        'conversation_id': widget.conversationId,
        'sender_id': userId,
        'body': text,
        'message_type': 'text',
      });
      _controller.clear();
      // Reload all messages after sending
      final data = await ref
          .read(apiServiceProvider)
          .getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = data
              .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    if (_uploadingAttachment) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || !mounted) return;

      setState(() => _uploadingAttachment = true);

      final mimeType = _mimeTypeFromFilename(file.name);
      final uploadResult = await ref.read(apiServiceProvider).uploadFile(
            bytes: bytes,
            filename: file.name,
            mimeType: mimeType,
          );
      if (!mounted) return;

      final userId = ref.read(authProvider).userId;
      await ref.read(apiServiceProvider).sendMessage({
        'conversation_id': widget.conversationId,
        'sender_id': userId,
        'body': file.name,
        'attachment_url': uploadResult['url'] as String,
        'attachment_filename': uploadResult['filename'] as String? ?? file.name,
        'message_type': 'file',
      });

      final data = await ref
          .read(apiServiceProvider)
          .getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = data
              .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File send failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  static String _mimeTypeFromFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(authProvider).userId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Conversation #${widget.conversationId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Error: $_error'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadMessages,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? const Center(
                            child: Text('No messages yet. Say hello!'))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (ctx, i) {
                              final m = _messages[i];
                              final isMe = m.senderId == currentUserId;
                              final bubble = Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isMe) ...[
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Theme.of(ctx)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.2),
                                        child: Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(ctx).size.width *
                                                0.65,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? Theme.of(ctx)
                                                .colorScheme
                                                .primary
                                            : Colors.grey[200],
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (m.messageType == 'file' &&
                                              m.attachmentUrl != null)
                                            _FileBubble(
                                              filename: m.attachmentFilename ??
                                                  m.body,
                                              url: m.attachmentUrl!,
                                              isMe: isMe,
                                            )
                                          else
                                            Text(
                                              m.body,
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${m.sentAt.hour.toString().padLeft(2, '0')}:${m.sentAt.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe
                                                  ? Colors.white70
                                                  : Colors.black38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isMe) const SizedBox(width: 6),
                                  ],
                                ),
                              );
                              if (!isMe) return bubble;
                              // Own messages support delete via double-tap or long-press
                              return GestureDetector(
                                onDoubleTap: () => _confirmDelete(m.id),
                                onLongPress: () => _confirmDelete(m.id),
                                child: bubble,
                              );
                            },
                          ),
          ),
          const Divider(height: 1),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Attachment button
                _uploadingAttachment
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.attach_file_outlined),
                        onPressed: _pickAndSendFile,
                        tooltip: 'Attach file',
                      ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small widget that renders a file attachment inside a chat bubble with a
/// download (open in browser) button.
class _FileBubble extends StatelessWidget {
  const _FileBubble({
    required this.filename,
    required this.url,
    required this.isMe,
  });

  final String filename;
  final String url;
  final bool isMe;

  static IconData _iconForFilename(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return Icons.image_outlined;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['doc', 'docx'].contains(ext)) return Icons.description_outlined;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart_outlined;
    if (['zip', 'rar'].contains(ext)) return Icons.folder_zip_outlined;
    return Icons.attach_file_outlined;
  }

  Future<void> _download() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isMe ? Colors.white : Colors.black87;
    final subColor = isMe ? Colors.white70 : Colors.black45;

    return InkWell(
      onTap: _download,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForFilename(filename), color: textColor, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13),
                ),
                Text(
                  'Tap to download',
                  style: TextStyle(color: subColor, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.download_outlined, color: textColor, size: 18),
        ],
      ),
    );
  }
}
