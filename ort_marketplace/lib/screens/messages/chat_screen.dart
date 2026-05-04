import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
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
      _ => 'application/pdf',  // safe fallback: treated as document
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

/// Small widget that renders a file attachment inside a chat bubble.
/// Images are displayed as inline previews with a fullscreen tap gesture.
/// Non-image files show a Download button that saves the file to the
/// device's local storage (or triggers a browser download on web).
class _FileBubble extends StatefulWidget {
  const _FileBubble({
    required this.filename,
    required this.url,
    required this.isMe,
  });

  final String filename;
  final String url;
  final bool isMe;

  static const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  static bool _isImage(String name) {
    final ext = name.split('.').last.toLowerCase();
    return _imageExts.contains(ext);
  }

  static IconData _iconForFilename(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (_imageExts.contains(ext)) return Icons.image_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['doc', 'docx'].contains(ext)) return Icons.description_outlined;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart_outlined;
    if (['zip', 'rar'].contains(ext)) return Icons.folder_zip_outlined;
    return Icons.attach_file_outlined;
  }

  @override
  State<_FileBubble> createState() => _FileBubbleState();
}

class _FileBubbleState extends State<_FileBubble> {
  double? _progress; // null = idle, 0..1 = downloading
  bool _done = false;

  void _showImageFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              widget.filename,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _download(context),
                tooltip: 'Download',
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: widget.url,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const CircularProgressIndicator(color: Colors.white),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    if (_progress != null) return; // already in progress

    // On web, fall back to opening the URL in a new tab.
    if (kIsWeb) {
      await launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);
      return;
    }

    setState(() {
      _progress = 0;
      _done = false;
    });

    try {
      // Pick a writable directory available on all platforms.
      late Directory dir;
      if (Platform.isAndroid) {
        // getExternalStorageDirectory returns the app-specific external dir
        // (e.g. /sdcard/Android/data/<pkg>/files) which doesn't need WRITE
        // permission on Android 10+.
        final ext = await getExternalStorageDirectory();
        dir = ext ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final savePath = '${dir.path}/${widget.filename}';
      final dio = Dio();
      await dio.download(
        widget.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );

      if (mounted) {
        setState(() {
          _progress = null;
          _done = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${widget.filename}'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _progress = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_FileBubble._isImage(widget.filename)) {
      return GestureDetector(
        onTap: () => _showImageFullscreen(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: widget.url,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 200,
              height: 100,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, size: 40),
            ),
          ),
        ),
      );
    }

    final textColor = widget.isMe ? Colors.white : Colors.black87;
    final subColor = widget.isMe ? Colors.white70 : Colors.black45;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_FileBubble._iconForFilename(widget.filename), color: textColor, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.filename,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13),
              ),
              if (_progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: textColor.withValues(alpha: 0.2),
                      color: textColor,
                    ),
                  ),
                )
              else
                Text(
                  _done ? 'Downloaded ✓' : 'Tap to download',
                  style: TextStyle(color: subColor, fontSize: 10),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (_progress != null)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: _progress,
              color: textColor,
            ),
          )
        else
          GestureDetector(
            onTap: () => _download(context),
            child: Icon(
              _done ? Icons.check_circle_outline : Icons.download_outlined,
              color: textColor,
              size: 20,
            ),
          ),
      ],
    );
  }
}
